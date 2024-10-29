# Mojolicious::Plugin::Datadog

Mojolicious::Plugin::Datadog is a plugin for the Mojolicious web framework that integrates with Datadog for monitoring and metrics.

## Installation

[TODO]

## Usage

To use the plugin in your Mojolicious application, add it to your `startup` method:

```perl
package MyApp;
use Mojo::Base qw(Mojolicious -signatures);

sub startup ($self) {
    # Add MFab::Plugins to the plugin namespace search
    push(@{ $self->plugins->namespaces }, 'MFab::Plugins');

    # Load the Datadog plugin
    $self->plugin('Datadog', { enabled => "true" });

    # Other startup code...
}
```

## Configuration

The plugin accepts the following configuration options:

- `datadogHost` - the datadog agent host, also looks in the ENV for `DD_AGENT_HOST`, defaults to `localhost`
- `enabled` - should we send traces to datadog, also looks in the ENV for `DD_TRACE_ENABLED`, defaults to `false`
- `serviceEnv` - the value to send to datadog for the service environment, defaults to `test`

## Features

- **Metrics Collection**: Automatically collect and send metrics to Datadog APM.
- **Datadog APM Ecosystem**: Automatically uses the Datadog headers to trace cross-app requests
- **Custom Metrics**: Define and send custom metrics from your application.

## Custom Metrics

In Datadog, traces can contain multiple spans. Each span can have a parent to describe the relationship between them. In order to include your own spans in the trace, they need to be associated with the Mojolicious transaction. Below is an example:

```perl
package MyWebserverApp;
use MFab::Plugins::Datadog qw(startSpan endSpan);
use Mojo::Base qw(Mojolicious::Controller -signatures);

sub request ($c) {
    my $span = startSpan($c->tx, "MyWebserverApp::request", "/requesturl");
    # process request
    $c->render(text => "Done");
    endSpan($span);
}
```

By default, the parent is associated with the active Mojolicious hook spans. You can also pass in a span to startSpan to use as the parent if you have 

## Contributing

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## Acknowledgments

- [Mojolicious](https://mojolicious.org/)
- [Datadog](https://www.datadoghq.com/)