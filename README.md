unscripted [![pub package](https://img.shields.io/pub/v/unscripted.svg)](https://pub.dartlang.org/packages/unscripted) [![Build Status](https://drone.io/github.com/seaneagan/unscripted/status.png)](https://drone.io/github.com/seaneagan/unscripted/latest) [![Coverage Status](https://img.shields.io/coveralls/seaneagan/unscripted.svg)](https://coveralls.io/r/seaneagan/unscripted?branch=master)
==========

*Define command-line interfaces using ordinary dart methods and classes.*

## Installation

```shell
pub global activate den
den install unscripted
```

## Usage

The following [greet.dart][greet.dart] script outputs a configurable greeting:

```dart
#!/usr/bin/env dart

import 'package:unscripted/unscripted.dart';

main(arguments) => new Script(greet).execute(arguments);

// All metadata annotations are optional.
@Command(help: 'Print a configurable greeting', plugins: const [const Completion()])
@ArgExample('--salutation Hi --enthusiasm 3 Bob', help: 'enthusiastic')
greet(
    @Rest(help: 'Name(s) to greet.')
    List<String> who, {
      @Group.start('Output');
      @Option(help: 'How many !\'s to append.')
      int enthusiasm : 0,
      @Flag(abbr: 'l', help: 'Put names on separate lines.')
      bool lineMode : false,
      @Option(name: 'greeting', help: 'Alternate word to greet with e.g. "Hi".')
      String salutation : 'Hello'
    }) {

  print(salutation +
        who.map((w) => (lineMode ? '\n  ' : ' ') + w).join(',') +
        '!' * enthusiasm);
}
```

We can call this script as follows:

```shell
$ greet.dart Bob
Hello Bob
$ greet.dart --enthusiasm 3 -l --greeting Hi Alice Bob
Hi
  Alice,
  Bob!!!
```

## Automatic --help

A `--help`/`-h` flag is automatically defined:

```shell
$ greet.dart --help

Description:

  Print a configurable greeting.

Usage:

  greet.dart [options] [<who>...]

    <who>    Name(s) to greet.

Options:

      --completion         Tab completion for this command.

            [install]      Install completion script to .bashrc/.zshrc.
            [print]        Print completion script to stdout.
            [uninstall]    Uninstall completion script from .bashrc/.zshrc.

  -h, --help               Print this usage information.

  Output:

      --enthusiasm         How many !'s to append.
                           (defaults to "0")

  -l, --line-mode          Put names on separate lines.
      --greeting           Alternate word to greet with e.g. "Hi".
                           (defaults to "Hello")

Examples:

  greet.dart --greeting Hi --enthusiasm 3 Bob # enthusiastic

```

## Sub-Commands

Sub-commands are represented as `SubCommand`-annotated instance methods of 
classes, as seen in the following [server.dart][server.dart]:

```dart
#!/usr/bin/env dart

import 'dart:io';

import 'package:unscripted/unscripted.dart';
import 'package:path/path.dart' as path;

main(arguments) => new Script(Server).execute(arguments);

class Server {

  final String configPath;

  @Command(
      help: 'Manages a server',
      plugins: const [const Completion()])
  Server({this.configPath: 'config.xml'});

  @SubCommand(help: 'Start the server')
  start({bool clean: false}) {
    print('''
Starting the server.
Config path: $configPath''');
  }

  @SubCommand(help: 'Stop the server')
  stop() {
    print('Stopping the server.');
  }

}
```

We can call this script as follows:

```shell
$ server.dart start --config-path my-config.xml --clean
Starting the server.
Config path: my-config.xml
```

Help is also available for sub-commands:

```shell
$ server.dart help

Available commands:

  start
  help
  stop

Use "server.dart help [command]" for more information about a command.

$ server.dart help stop

Description:

  Stop the server

Usage:

  server.dart stop [options]

Options:

  -h, --help    Print this usage information.
```

## Parsers

Any value-taking argument (option, positional, rest) can have a "parser"
responsible for validating and transforming the string passed on the command 
line.  You can give an argument a parser simply by giving it a type (such as 
`int` or `DateTime`) which has a static `parse` method, or by specifying the 
`parser` named argument of the argument's metadata (`Option`, `Positional`, or 
`Rest`).

## Plugins

Plugins allow you to mixin reusable chunks of cli-specific functionality 
(options/flags/commands) on top of your base interface.

To add a plugin to your script, just add an instance of the associated plugin
class to the `plugins` named argument of your `@Command` annotation.  The 
following plugins are available:

### Tab Completion

Add bash/zsh [tab completion][tab completion] to your script:

```dart
@Command(/*...*/ plugins: const [const Completion()])
```

If your script already has sub-commands, this will add a `completion` 
sub-command (similar to [npm completion][npm completion]), otherwise it adds a 
`--completion` option.  These can then be used as follows:

```shell
# Try the tab-completion without permanently installing.
. <(greet.dart --completion print)
. <(server.dart completion print)

# Install the completion script to .bashrc/.zshrc depending on current shell.
# No-op if already installed.
greet.dart --completion install
server.dart completion install

# Uninstall a previously installed completion script.
# No-op if not installed.
greet.dart --completion uninstall
server.dart completion uninstall
```

Once installed, the user will be able to tab-complete all aspects of your cli,
for example:

**Option/Flag names:** Say your script is a dart method with a 
`longOptionName` named parameter.  This becomes `--long-option-name` in your 
cli, and once completion is installed, the user can type `--l[TAB]` and it will 
be completed to `--long-option-name`.  It will also expand short options to their 
long equivalents, e.g. `-vh[TAB]` becomes `--verbose --help`.

**Commands:** If your script is a dart class having a `@SubCommand() 
longCommandName` method, that becomes a `long-command-name` sub-command in your 
cli, and the user can type `l[TAB]` and it will be completed to 
`long-command-name`.

**Option/Positional/Rest values:** The `allowed` named parameter of `Option`,
`Positional`, and `Rest` specifies the allowed values, and thus completions, 
for those parameters.  For example if you have 
`@Option(allowed: const ['red', 'yellow', 'green']) textColor`, and the user 
types `--text-color g[TAB]` this will become `--text-color green`.  `allowed` 
can also be a callback of one of the following forms: 

```dart
Iterable<String> complete(String text);
Iterable<String> complete();
Future<Iterable<String>> complete(String text);
Future<Iterable<String>> complete();
```

where if an arg (e.g. `text` here) is specified, it represents the last partial 
word typed by the user when completion is requested, which can be used to filter
the results to match that prefix.  If the arg is omitted, the filtering is done
automatically for you.  For example if the option/positional/rest represents a 
file name, you could emulate the builtin shell file name completion by returning 
a list of filenames in the current directory.

Tab completion is supported in [cygwin][cygwin], with one minor bug (#64).

### Other Plugins

There are several other plugins planned, and also the ability to write your own
is planned, see #62.

## Demo

[den][] uses a large subset of the features above.  Run `pub global activate den`
to install, and then `den -h` to get a feel for the UX provided by unscripted.

[pkg]: http://pub.dartlang.org/packages/unscripted
[den]: https://github.com/seaneagan/den
[examples]: https://github.com/seaneagan/unscripted/tree/master/example
[greet.dart]: https://github.com/seaneagan/unscripted/tree/master/example/greet.dart
[server.dart]: https://github.com/seaneagan/unscripted/tree/master/example/server.dart
[old_greet]: https://github.com/seaneagan/unscripted/tree/master/example/old_greet.dart
[tab completion]: http://en.wikipedia.org/wiki/Command-line_completion
[cygwin]: http://en.wikipedia.org/wiki/Cygwin
[npm completion]: https://www.npmjs.org/doc/cli/npm-completion.html
