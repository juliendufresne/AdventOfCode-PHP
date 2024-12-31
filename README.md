# AdventOfCode with PHP

My take on the AdventOfCode.com puzzles.

## Getting Started

> [!NOTE]
> If you are using Windows, please consider using [wsl](https://learn.microsoft.com/en-us/windows/wsl/).

1. If not already done, [install Docker Compose](https://docs.docker.com/compose/install/) (v2.10+) and Make
2. Run `make build` to build fresh images
3. Run `make up` to set up and start a fresh Symfony project
4. Once done, run `make down` to stop the Docker containers.

> [!TIP]
> Run `make help` to see all available commands

## Debugging

The default development image is shipped with [Xdebug](https://xdebug.org/),
a popular debugger and profiler for PHP.

Because it has a significant performance overhead, the step-by-step debugger is disabled by default.
It can be enabled by setting the `XDEBUG_MODE` environment variable to `debug`.

On Linux and Mac:

```bash
make debug
```

On Windows (without wsl):

```shell
# Windows CMD
set XDEBUG_MODE=debug&& docker compose up -d&set XDEBUG_MODE=
# Windows PowerShell
$env:XDEBUG_MODE="debug"; docker compose up -d; Remove-Item Env:XDEBUG_MODE
```

### Debugging with Xdebug and PHPStorm

First, [create a PHP debug remote server configuration](https://www.jetbrains.com/help/phpstorm/creating-a-php-debug-server-configuration.html):

1. In the `Settings/Preferences` dialog, go to `PHP | Servers`
2. Create a new server:
    * Name: `symfony` (or whatever you want to use for the variable `PHP_IDE_CONFIG`)
    * Host: `localhost` (or the one defined using the `SERVER_NAME` environment variable)
    * Port: `443`
    * Debugger: `Xdebug`
    * Check `Use path mappings`
    * Absolute path on the server: `/app`

You can now use the debugger!

1. In PHPStorm, open the `Run` menu and click on `Start Listening for PHP Debug Connections`
2. On command line, we might need to tell PHPStorm which [path mapping configuration](https://www.jetbrains.com/help/phpstorm/zero-configuration-debugging-cli.html#configure-path-mappings) should be used, set the value of the PHP_IDE_CONFIG environment variable to `serverName=symfony`, where `symfony` is the name of the debug server configured higher.

   Example:

    ```console
    XDEBUG_SESSION=1 PHP_IDE_CONFIG="serverName=symfony" php bin/console ...
    ```

> [!NOTE]
> If you use another name than `symfony` as server name, create or edit `.env.local` file and add a line:
> `XDEBUG_SERVER_NAME=your-server-name-here`
> That way, `make debug` will output the right command
