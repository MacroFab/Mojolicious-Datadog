# Example Webserver

This is a test Mojolicious web application that demonstrates various endpoints and Datadog tracing integration.

## Running the Server

The server can be run using Docker Compose:

```bash
docker-compose up --build
```

The server will be available at http://localhost:4301

## Available Endpoints

- `GET /` - Returns a simple text response
- `GET /restart` - Restarts the hypnotoad server
- `GET /some/specific/route/:id` - Returns a response with the provided ID parameter
- `GET /sleep10` - Synchronous 10-second delay endpoint
- `GET /sleep10-async` - Asynchronous 10-second delay endpoint
- `GET /loopget` - Makes a request to the root endpoint
- `GET /recurse-sleep` - Makes an async request to /sleep10-async with Datadog tracing

## Configuration

The server runs on port 4301 and includes the following environment settings:
- `MOJO_INACTIVITY_TIMEOUT=600`
- `DD_TRACE_ENABLED=false`
- `DD_INSTRUMENTATION_TELEMETRY_ENABLED=false`

You can modify these settings in the `docker-compose.yml` file.
