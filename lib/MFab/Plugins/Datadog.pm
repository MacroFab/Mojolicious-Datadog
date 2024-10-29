package MFab::Plugins::Datadog;

=encoding utf8

=head1 NAME

MFab::Plugins::Datadog - Testing sending APM traces to Datadog in Mojolicious

=head1 NOTES

If the worker is killed through a heartbeat failure, the spans for that worker won't be sent

Websockets only generate a mojolicious-transaction span

=cut

use Mojo::Base qw(Mojolicious::Plugin -signatures);

use Time::HiRes qw(gettimeofday tv_interval);
use Crypt::Random;
use Math::Pari;

use Exporter 'import';
our @EXPORT_OK = qw(startSpan endSpan);

# Keep track of all outstanding transactions
my(%transactions);

=item datadogId()

Generate a 64 bit integer that JSON::XS will serialize as an integer

=cut

sub datadogId () {
	my $id = Crypt::Random::makerandom(Size => 64, Strength => 0);
	return Math::Pari::pari2iv($id);
}

=item configItem($config_host)

Get the config item from: the app setting, the environment variable, or use the default

=cut

sub configItem ($appSetting, $envName, $default) {
	if(not $appSetting) {
		$appSetting = $ENV{$envName} || $default;
	}
	return $appSetting;
}

=item setTraceId($c, $connection_data)

Set the traceid in the connection data

=cut

sub setTraceId ($tx, $connection_data) {
	if(defined $connection_data->{traceid}) {
		return;
	}

	$connection_data->{traceid} = $tx->req->headers->header("x-datadog-trace-id");
	if($connection_data->{traceid}) {
		$connection_data->{traceid} = int($connection_data->{traceid});
	} else {
		$connection_data->{traceid} = datadogId();
		$tx->req->headers->header("x-datadog-trace-id" => $connection_data->{traceid});
	}
}

=item aroundActionHook()

The around_action hook - wrapped around the action

=cut

sub aroundActionHook ($next, $c, $action, $last) {
	my $connection_data = $transactions{$c->tx} || {};

	$connection_data->{action_start} = [gettimeofday()];
	$connection_data->{action_spanid} = datadogId();
	$connection_data->{current_spanid} = $connection_data->{dispatch_spanid};
	$connection_data->{after_dispatch} = 0;

	setTraceId($c->tx, $connection_data);

	$connection_data->{parentid} = $c->tx->req->headers->header("x-datadog-parent-id");
	if($connection_data->{parentid}) {
		$connection_data->{parentid} = int($connection_data->{parentid});
	}
	$c->tx->req->headers->header("x-datadog-parent-id" => $connection_data->{action_spanid});

	my $retval = $next->();

	$connection_data->{action_duration} = tv_interval($connection_data->{action_start});
	$connection_data->{is_sync} = $connection_data->{after_dispatch};

	my $route = $c->match->endpoint;
	# "/" doesn't have a pattern
	$connection_data->{pattern} = $route->pattern->unparsed || $c->req->url;

	return $retval;
}

=item afterDispatchHook()

The after_dispatch hook - called after the request is finished the sync stage of processing, more async processing can happen after this

=cut

sub afterDispatchHook ($c) {
	my $connection_data = $transactions{$c->tx} || {};

	if(not defined($connection_data->{action_start})) {
		$connection_data->{action_start} = [gettimeofday()];
	}

	setTraceId($c->tx, $connection_data);

	$connection_data->{after_dispatch} = 1;
	$connection_data->{current_spanid} = $connection_data->{dispatch_spanid};
	$connection_data->{dispatch_duration} = tv_interval($connection_data->{action_start});
}

=item afterBuildTxHook()

The after_build_tx hook - called after the transaction is built but before it is parsed

=cut

sub afterBuildTxHook ($tx, $app, $args) {
	my $connection_data = {
		spans => [],
	};
	$transactions{$tx} = $connection_data;
	$connection_data->{tx_spanid} = datadogId();
	$connection_data->{dispatch_spanid} = datadogId();
	$connection_data->{current_spanid} = $connection_data->{tx_spanid};
	$connection_data->{build_tx_start} = [gettimeofday()];

	$tx->on(finish => sub ($tx) {
		# websockets skip dispatch & action hooks
		setTraceId($tx, $connection_data);
		$connection_data->{url} = $tx->req->url->path;
		$connection_data->{method} = $tx->req->method;
		$connection_data->{code} = $tx->res->code;
		$connection_data->{tx_duration} = tv_interval($connection_data->{build_tx_start});
		submitDatadog($app, $connection_data, $args);
		$transactions{$tx} = undef;
	});
}

=item register()

Register Mojolicious plugin and hook into the application

=cut

sub register ($self, $app, $args) {
	if(not $args->{service}) {
		$args->{service} = "MFab::Plugins::Datadog";
	}
	$args->{datadogHost} = configItem($args->{datadogHost}, "DD_AGENT_HOST", "localhost");
	$args->{enabled} = configItem($args->{enabled}, "DD_TRACE_ENABLED", "false") eq "true";
	$args->{datadogURL} = "http://".$args->{datadogHost}.":8126/v0.3/traces";
	$args->{serviceEnv} = $args->{serviceEnv} || "test";

	if($args->{enabled}) {
		$app->hook(around_action => \&aroundActionHook);
		$app->hook(after_dispatch => \&afterDispatchHook);
		$app->hook(after_build_tx => sub ($tx, $app) { afterBuildTxHook($tx, $app, $args) });
	}
}

=item startSpan($tx, $name, $resource, [$parent_id])

Start a new span, associates it to the transaction via $tx

=cut

sub startSpan ($tx, $name, $resource, $parent_id = undef) {
	# we don't have a transaction, so we can't send this span
	if(not defined($tx)) {
		return {
			"no_tx" => 1,
		};
	}
	my $connection_data = $transactions{$tx} || {};
	my $span = {
		"name" => $name,
		"resource" => $resource,
		"start" => [gettimeofday()],
		"span_id" => datadogId(),
		"parent_id" => $parent_id || $connection_data->{current_spanid},
		"type" => "web",
		"meta" => {},
	};
	push(@{$connection_data->{spans}}, $span);
	return $span;
}

=item endSpan($span, [$error_message])

End a span, optional error message

=cut

sub endSpan ($span, $error_message = undef) {
	if($span->{no_tx}) {
		return;
	}
	# we've already submitted this span, likely due to a timeout
	if($span->{meta}{"mojolicious.unclosed"} or ref($span->{start}) ne "ARRAY") {
		return;
	}
	$span->{duration} = durationToDatadog(tv_interval($span->{start}));
	$span->{start} = timestampToDatadog($span->{start});
	if($error_message) {
		$span->{error} = 1;
		$span->{meta} = { "error.message" => "$error_message" };
	}
}

=item timestampToDatadog($timestamp)

Datadog wants number of nanoseconds since the epoch

=cut

sub timestampToDatadog ($timestamp) {
	if (not defined($timestamp)) {
		return undef;
	}
	return $timestamp->[0] * 1000000000 + $timestamp->[1] * 1000;
}

=item durationToDatadog($duration)

Datadog wants duration in nanoseconds

=cut

sub durationToDatadog ($duration) {
	if (not defined($duration)) {
		return undef;
	}
	return int($duration * 1000000000);
}

=item submitDatadog($app, $connection_data, $args)

Submit spans to datadog agent

=cut

sub submitDatadog ($app, $connection_data, $args) {
	my $pattern = $connection_data->{pattern} || $connection_data->{url};
	my $is_sync = $connection_data->{is_sync} || 0;
	my %meta = (
		"env" => $args->{serviceEnv},
		"api.endpoint.route" => $pattern,
		"http.path_group" => $connection_data->{pattern},
		"http.method" => $connection_data->{method},
		"http.url_details.path" => $connection_data->{url},
		"process_id" => "$$",
		"language" => "perl",
		"mojolicious.sync" => "$is_sync",
	);
	if(defined($connection_data->{code})) {
		$meta{"http.status_code"} = "".$connection_data->{code};
	}

	my @spans = @{$connection_data->{spans}};

	for my $span (@spans) {
		$span->{meta}{env} = $meta{env};
		$span->{meta}{process_id} = "$$";
		$span->{meta}{language} = "perl";
		$span->{trace_id} = $connection_data->{traceid};
		if(not defined($span->{duration})) {
			$span->{duration} = durationToDatadog(tv_interval($span->{start}));
			$span->{start} = timestampToDatadog($span->{start});
			$span->{meta}{"mojolicious.unclosed"} = "true";
			$span->{error} = 1;
			$span->{meta} = { "error.message" => "Span was not finished when it was sent to the platform" };
		}

		$span->{service} = $args->{service};
	}

	if(defined($connection_data->{action_duration})) {
		push(@spans, 
			{
				"duration" => durationToDatadog($connection_data->{action_duration}),
				"meta" => \%meta,
				"name" => "mojolicious-action",
				"resource" => $pattern,
				"service" => $args->{service},
				"span_id" => $connection_data->{action_spanid},
				"start" => timestampToDatadog($connection_data->{action_start}),
				"trace_id" => $connection_data->{traceid},
				"parent_id" => $connection_data->{tx_spanid},
				"type" => "web",
			});
	}

	if($connection_data->{after_dispatch}) {
		push(@spans,
			{
				"duration" => durationToDatadog($connection_data->{dispatch_duration}),
				"meta" => \%meta,
				"name" => "mojolicious-dispatch",
				"resource" => $pattern,
				"service" => $args->{service},
				"span_id" => $connection_data->{dispatch_spanid},
				"start" => timestampToDatadog($connection_data->{action_start}),
				"trace_id" => $connection_data->{traceid},
				"parent_id" => $connection_data->{tx_spanid},
				"type" => "web",
			}
		);
	}

	my $tx_span = {
		"duration" => durationToDatadog($connection_data->{tx_duration}),
		"meta" => \%meta,
		"name" => "mojolicious-transaction",
		"resource" => $pattern,
		"service" => $args->{service},
		"span_id" => $connection_data->{tx_spanid},
		"start" => timestampToDatadog($connection_data->{build_tx_start}),
		"trace_id" => $connection_data->{traceid},
		"type" => "web",
	};
	if($connection_data->{parentid}) {
		$tx_span->{"parent_id"} = $connection_data->{parentid};
	}
	push(@spans, $tx_span);

	$app->ua->put($args->{datadogURL}, json => [ \@spans ], sub ($ua, $tx) {
		if($tx->res->is_error) {
			$app->log->error("HTTP Error sending to datadog: ".$tx->res->code." ".$tx->res->body);
			return;
		}
		# Errors without a HTTP status code like connection refused & timeout
		if($tx->res->error) {
			$app->log->error("Error sending to datadog: ".$tx->res->error->{message});
			return;
		}
	});
}

1;