
library usage_completion_test;

import 'dart:async';

import 'package:unscripted/unscripted.dart';
import 'package:unscripted/src/plugins/completion/completion.dart' as completion_plugin;
import 'package:unscripted/src/plugins/completion/command_line.dart';
import 'package:unscripted/src/plugins/completion/usage_completion.dart';
import 'package:unscripted/src/usage.dart';
import 'package:unscripted/src/plugins/help/help.dart';
import 'package:test/test.dart';

addPlugins(Usage usage) {
  [const completion_plugin.Completion(), const Help()].forEach((plugin) {
    plugin.updateUsage(usage);
  });
}

main() {

  // Assumes no spaces within arguments, cursor at end of line.
  // That is tested in the CommandLine tests.
  CommandLine makeSimpleCommandLine(String line) {
    line = 'foo $line';
    var args = line.split(new RegExp(r'\s+'));
    var cWord = args.length - 1;
    if(args.last == '') args.removeLast();
    return new CommandLine(args, environment: {
      'COMP_LINE' : line,
      'COMP_POINT': line.length.toString(),
      'COMP_CWORD': cWord.toString()
    });
  }

  testAllowed(Usage usage, String line, expectedCompletions) {
    var completions = getUsageCompletions(usage, makeSimpleCommandLine(line));
    expect(completions, completion(expectedCompletions));
  }

  group('getUsageCompletions', () {

    group('when usage empty', () {

      test('should complete -- to to plugin options', () {
        var usage = new Usage();
        addPlugins(usage);
        testAllowed(usage, '--', [
          '--completion',
          '--help'
        ]);
      });

    });

    group('when completing long option', () {

      test('should suggest all long options for -- or empty', () {
        var usage = new Usage()
            ..addOption(new Option(name: 'aaa'))
            ..addOption(new Option(name: 'bbb'));
        addPlugins(usage);

        testAllowed(usage, '', [
          '--aaa',
          '--bbb',
          '--completion',
          '--help'
        ]);

        testAllowed(usage, '--', [
          '--aaa',
          '--bbb',
          '--completion',
          '--help'
        ]);
      });

      test('should suggest long options with same prefix', () {
        var usage = new Usage()
            ..addOption(new Option(name: 'aaa'))
            ..addOption(new Option(name: 'bbb'));
        addPlugins(usage);

        testAllowed(usage, '--a', ['--aaa']);
      });

    });

    test('should complete - to --', () {
      var usage = new Usage()
          ..addOption(new Option(name: 'opt', abbr: 'o'));
      addPlugins(usage);

      testAllowed(usage, '-', [
        '--opt',
        '--completion',
        '--help'
      ]);
    });

    test('should complete short option to long option', () {
      var usage = new Usage()
          ..addOption(new Option(name: 'opt', abbr: 'o'))
          ..addOption(new Flag(name: 'flag', abbr: 'f'));
      addPlugins(usage);

      testAllowed(usage, '-o', [['--opt']]);
      testAllowed(usage, '-f', [['--flag']]);
      testAllowed(usage, '-hf', [['--help', '--flag']]);
    });

    group('when completing option value', () {

      test('should suggest allowed', () {
        var usage = new Usage()
            ..addOption(new Option(name: 'aaa', abbr: 'a', allowed: ['x', 'y', 'z']))
            ..addOption(new Option(name: 'bbb', abbr: 'b', allowed: {'x': '', 'y': '', 'z': ''}))
            ..addOption(new Option(name: 'ccc', abbr: 'c'))
            ..addOption(new Flag(name: 'flag', abbr: 'f'));
        addPlugins(usage);

        testAllowed(usage, '--aaa ', ['x', 'y', 'z']);
        testAllowed(usage, '-a ', ['x', 'y', 'z']);
        testAllowed(usage, '--bbb ', ['x', 'y', 'z']);
        testAllowed(usage, '-b ', ['x', 'y', 'z']);
        testAllowed(usage, '--ccc ', []);
        testAllowed(usage, '-c ', []);
        testAllowed(usage, '-f ', []);
      });

      group('when allowed is a unary func', () {

        test('should suggest synchronously returned completions', () {
          var usage = new Usage()
              ..addOption(new Option(name: 'aaa', abbr: 'a', allowed: (partial) => ['x', 'y', 'z']));
          addPlugins(usage);

          testAllowed(usage, '--aaa ', ['x', 'y', 'z']);
          testAllowed(usage, '--aaa x', ['x', 'y', 'z']);
          testAllowed(usage, '-a ', ['x', 'y', 'z']);
          testAllowed(usage, '-a x', ['x', 'y', 'z']);
        });

        test('should suggest asynchronously returned completions', () {
          var usage = new Usage()
              ..addOption(new Option(name: 'aaa', abbr: 'a', allowed: (partial) => new Future.value(['x', 'y', 'z'])));
          addPlugins(usage);

          testAllowed(usage, '--aaa ', ['x', 'y', 'z']);
          testAllowed(usage, '--aaa x', ['x', 'y', 'z']);
          testAllowed(usage, '-a ', ['x', 'y', 'z']);
          testAllowed(usage, '-a x', ['x', 'y', 'z']);
        });
      });

      group('when allowed is a nullary func', () {

        test('should suggest synchronously returned completions', () {
          var usage = new Usage()
              ..addOption(new Option(name: 'aaa', abbr: 'a', allowed: () => ['x', 'y', 'z']));
          addPlugins(usage);

          testAllowed(usage, '--aaa ', ['x', 'y', 'z']);
          testAllowed(usage, '--aaa x', ['x']);
          testAllowed(usage, '-a ', ['x', 'y', 'z']);
          testAllowed(usage, '-a x', ['x']);
        });

        test('should suggest asynchronously returned completions', () {
          var usage = new Usage()
              ..addOption(new Option(name: 'aaa', abbr: 'a', allowed: () => new Future.value(['x', 'y', 'z'])));
          addPlugins(usage);

          testAllowed(usage, '--aaa ', ['x', 'y', 'z']);
          testAllowed(usage, '--aaa x', ['x']);
          testAllowed(usage, '-a ', ['x', 'y', 'z']);
          testAllowed(usage, '-a x', ['x']);
        });
      });

    });

    group('when completing positional value', () {

      test('should suggest allowed', () {
        var usage = new Usage()
            ..addPositional(new Positional(allowed: ['aa', 'bb', 'cc']))
            ..addPositional(new Positional(allowed: {'aa': '', 'bb': '', 'cc': ''}));
        addPlugins(usage);

        testAllowed(usage, '', ['aa', 'bb', 'cc']);
        testAllowed(usage, 'a', ['aa']);
        testAllowed(usage, 'aa b', ['bb']);
      });

      group('when allowed is a unary func', () {

        test('should suggest synchronously returned completions', () {
          var usage = new Usage()
              ..addPositional(new Positional(allowed: (partial) => ['aa', 'bb', 'cc']));
          addPlugins(usage);

          testAllowed(usage, '', ['aa', 'bb', 'cc']);
          testAllowed(usage, 'a', ['aa', 'bb', 'cc']);
        });

        test('should suggest asynchronously returned completions', () {
          var usage = new Usage()
              ..addPositional(new Positional(allowed: (partial) => new Future.value(['aa', 'bb', 'cc'])));
          addPlugins(usage);

          testAllowed(usage, '', ['aa', 'bb', 'cc']);
          testAllowed(usage, 'a', ['aa', 'bb', 'cc']);
        });

      });

      group('when allowed is a nullary func', () {

        test('should suggest synchronously returned completions', () {
          var usage = new Usage()
              ..addPositional(new Positional(allowed: () => ['aa', 'bb', 'cc']));
          addPlugins(usage);

          testAllowed(usage, '', ['aa', 'bb', 'cc']);
          testAllowed(usage, 'a', ['aa']);
        });

        test('should suggest asynchronously returned completions', () {
          var usage = new Usage()
              ..addPositional(new Positional(allowed: () => new Future.value(['aa', 'bb', 'cc'])));
          addPlugins(usage);

          testAllowed(usage, '', ['aa', 'bb', 'cc']);
          testAllowed(usage, 'a', ['aa']);
        });

      });

      test('should suggest allowed for rest parameter', () {
        var usage = new Usage()
            ..addPositional(new Positional())
            ..rest = new Rest(allowed: ['aa', 'bb', 'cc']);
        addPlugins(usage);

        testAllowed(usage, 'x ', ['aa', 'bb', 'cc']);
        testAllowed(usage, 'x aa b', ['bb']);
      });

    });

    group('when completing a command', () {

      test('should suggest available commands', () {
        var usage = new Usage()
            ..addCommand('xcommand')
            ..addCommand('ycommand');
        addPlugins(usage);

        testAllowed(usage, '', ['xcommand', 'ycommand', 'completion', 'help']);
      });

      test('should suggest commands matching incomplete word', () {
        var usage = new Usage()
            ..addPositional(new Positional())
            ..addCommand('xcommand')
            ..addCommand('ycommand');
        addPlugins(usage);

        testAllowed(usage, 'x', ['xcommand']);
      });

    });

  });

}
