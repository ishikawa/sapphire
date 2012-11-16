require "test/unit"
require "sapphire/perl_generator"

=begin
TEMPLATE:
    assert_code <<-EXPECTED, <<-ACTUAL
    EXPECTED
    ACTUAL
=end

class TestPerlGenerator < Test::Unit::TestCase
  def setup
    @generator = Sapphire::PerlGenerator.new nil, nil
  end

  def assert_code(expected, actual)
    assert_equal expected.gsub(/^ +/, ''), @generator.generate(actual)
  end

  def test_generate_general
    assert_code '1 + 1;', '1 + 1'
    assert_code 'method_call("abc");', 'method_call "abc"'
    assert_code 'inner(outer("abc"));', 'inner outer("abc")'
    assert_code 'my $var = 1;', 'var = 1'
    assert_code 'my @ary = (1, 2, 3);', 'ary = [1, 2, 3]'
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var = "foo";
      $var = "bar";
    EXPECTED
      var = 'foo'
      var = 'bar'
    ACTUAL
  end

  def test_generate_dstr
    assert_code '"Hello, " . world() . "!"', '"Hello, #{world}!"'
    assert_code '"" . hello() . ", world!"', '"#{hello}, world!"'
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $world = "world";
      "Hello, " . $world . "!"
    EXPECTED
      world = 'world'
      "Hello, \#{world}!"
    ACTUAL
  end

  def test_generate_if
    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
      else {
        do_other()
      }
    EXPECTED
      if bool
        do_something
      else
        do_other
      end
    ACTUAL

    # TODO: how to handle dangling elses
    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
      else {
        if (bool2()) {
          do_anotherthing()
        }
        else {
          do_other()
        }

      }
    EXPECTED
      if bool
        do_something
      elsif bool2
        do_anotherthing
      else
        do_other
      end
    ACTUAL

    # TODO
    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
      else {
        do_other()
      }
    EXPECTED
      bool ? do_something : do_other
    ACTUAL

    # TODO
    assert_code <<-EXPECTED, <<-ACTUAL
      if (bool()) {
        do_something()
      }
    EXPECTED
      do_something if bool
    ACTUAL
  end

  def test_generate_unless
    assert_code <<-EXPECTED, <<-ACTUAL
      unless (bool()) {
        do_something()
      }
    EXPECTED
      do_something unless bool
    ACTUAL
  end

=begin
  def test_generate_case
    assert_code <<-EXPECTED, <<-ACTUAL
      if ($val eq "abc") {
        print("abc" . "\n");
      }
      elsif ($val eq "def") {
        print("def" . "\n");
      }
      else {
        print("else" . "\n");
      }
    EXPECTED
      case val
      when 'abc'
        puts 'abc'
      when 'def'
        puts 'def'
      else
        puts 'else'
      end
    ACTUAL
  end
=end

  def test_generate_while
    assert_code <<-EXPECTED, <<-ACTUAL
      while (true) {
        do_something();
      }
    EXPECTED
      while (true)
        do_something
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      my $count = 0;
      while (true) {
        do_something();
        $count = $count + 1;
        if (5 < $count) {
          break;
        }

      }
    EXPECTED
      count = 0
      while (true)
        do_something
        count += 1
        break if 5 < count ;
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      while (true) {
        do_something();
        next;
      }
    EXPECTED
      while (true)
        do_something
        next
      end
    ACTUAL
  end

  def test_generate_until
    assert_code <<-EXPECTED, <<-ACTUAL
      my $count = 0;
      until (2 <= $count) {
        do_something();
        $count = $count + 1;
      }
    EXPECTED
      count = 0
      until (2 <= count)
        do_something
        count += 1
      end
    ACTUAL
  end

  def test_generate_scope
    assert_code <<-EXPECTED, <<-ACTUAL
      my $var1 = 0;
      if (true) {
        $var1 = 1;
        my $var2 = 2;
      }
    EXPECTED
      var1 = 0
      if true
        var1 = 1
        var2 = 2
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      my $var1 = 0;
      while (true) {
        $var1 = 1;
        my $var2 = 2;
      }
    EXPECTED
      var1 = 0
      while true
        var1 = 1
        var2 = 2
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $var1 = 0;
      while (true) {
        $var1 = 1;
        my $var2 = 2;
        if (true) {
          $var1 = 2;
          $var2 = 3;
          my $var3 = 3;
        }

      }

      my $var3 = 0;
    EXPECTED
      var1 = 0
      while true
        var1 = 1
        var2 = 2
        if true
          var1 = 2
          var2 = 3
          var3 = 3
        end
      end
      var3 = 0
    ACTUAL
  end

  def test_generate_defun
    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift;
        my $buzz = shift;
        print($bar . "\\n");
        print($buzz . "\\n");
      }
    EXPECTED
      def foo(bar, buzz)
        puts bar
        puts buzz
      end
    ACTUAL

=begin
    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift || 1;
      }
    EXPECTED
      def foo(bar=1)
      end
    ACTUAL
=end

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $bar = shift;
        my @buzz = @_;
        print($bar . "\\n");
        print($buzz[0] . "\\n");
      }
    EXPECTED
      def foo(bar, *buzz)
        puts bar
        puts buzz[0]
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my @bar = @_;
        my $buzz = $bar[0];
        my $xyzzy = $bar[1];

      }
    EXPECTED
      def foo(*bar)
        buzz, xyzzy = *bar
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      sub foo {
        my $block = shift;
        $block->(1, 2, 3);
      }
    EXPECTED
      def foo(&block)
        block.call 1, 2, 3
      end
    ACTUAL
  end

  def test_generate_funcall
    assert_code <<-EXPECTED.strip, <<-ACTUAL
      func(arg1(), arg2());
    EXPECTED
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $arg2 = undef;
      func(arg1(), $arg2);
    EXPECTED
      arg2 = nil
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $arg2 = undef;
      my $arg3 = undef;

      func(arg1(), $arg2);
    EXPECTED
      arg2, arg3 = nil, nil
      func arg1, arg2
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      outer(inner(arg1(), arg2()));
    EXPECTED
      outer inner(arg1, arg2)
    ACTUAL

    # TODO
    assert_code <<-EXPECTED, <<-ACTUAL
      for my $e (ary()) {
        print($e . "\\n");
      }
    EXPECTED
      ary.each do |e|
        puts e
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      sub func {
        my $block = shift;
        $block->(1, 2);
      }

      func(sub {
          my $arg1 = shift;
          my $arg2 = shift;
          my $arg3 = $arg1 + $arg2;
        }
      );
    EXPECTED
      def func(&block)
        block.call 1, 2
      end
      func do |arg1, arg2|
        arg3 = arg1 + arg2
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      sub func {
        my $arg1 = shift;
        my $arg2 = shift;
        my $block = shift;
        $block->($arg1, $arg2);
      }

      func(arg1(), arg2(), sub {
          my $arg3 = shift;
          my $arg4 = shift;
          my $arg5 = $arg3 + $arg4;
        }
      );
    EXPECTED
      def func(arg1, arg2, &block)
        block.call arg1, arg2
      end
      func arg1, arg2 do |arg3, arg4|
        arg5 = arg3 + arg4
      end
    ACTUAL

    assert_code <<-EXPECTED.strip, <<-ACTUAL
      my $a = 1;
      my $b = -($a);
      my $c = true;
      my $d = !($c);
      func(-($b), !($d));
    EXPECTED
      a = 1
      b = -a
      c = true
      d = !c
      func -b, !d
    ACTUAL
  end

  def test_generate_class
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Foo;
        use base 'Bar';
        sub buzz {
          my $self = shift;

        }

      }
    EXPECTED
      class Foo < Bar
        def buzz
        end
      end
    ACTUAL
  end

  def test_generate_module
    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Abc::Gef::A;
        use base 'Class::Accessor::Fast';

      }
    EXPECTED
      module Abc
        module Gef
          class A
          end
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Abc::Def::Jkl::Mno::B;
        use base 'Class::Accessor::Fast';

      }
    EXPECTED
      module Abc
        module Def
          module Jkl::Mno
            class B
            end
          end
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Foo;
        use base 'Class::Accessor::Fast';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Bar;
        use base 'Buzz::Xyzzy::Abc::Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Bar < Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Fuga;
        use base 'Buzz::Xyzzy::Abc::Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class ::Fuga < Foo
        end
      end
    ACTUAL

    assert_code <<-EXPECTED, <<-ACTUAL
      {
        package Buzz::Xyzzy::Abc::Piyo;
        use base 'Foo';

      }
    EXPECTED
      module Buzz::Xyzzy::Abc
        class Piyo < ::Foo
        end
      end
    ACTUAL
  end
end
