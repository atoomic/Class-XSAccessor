#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    if ($] < 5.010000) {
        print "1..0 # Skip entersub optimization not enabled", $/;
        exit;
    }
}

use Test::More tests => 103;
# use Test::More qw(no_plan);
use Data::Dumper; $Data::Dumper::Terse = $Data::Dumper::Indent = 1;

our @WARNINGS = ();

use Class::XSAccessor
    constructor => 'new',
    __tests__   => [ qw(foo bar) ];

sub baz {
    my $self = shift;
    @_ ? $self->{baz} = shift : $self->{baz}
}

# standard: verify that the subs work as expected
sub test1 {
    my $self = shift;
    is($self->foo('foo1'), 'foo1');
    is($self->foo(), 'foo1');
    is($self->{foo}, 'foo1');
    is($self->bar('bar1'), 'bar1');
    is($self->bar(), 'bar1');
    is($self->{bar}, 'bar1');
}

# loop: verify that the second time through, the optimized entersub is called
sub test2 {
    my $self = shift;
    for (1 .. 2) {
        is($self->foo('foo2'), 'foo2');
        is($self->foo(), 'foo2');
        is($self->{foo}, 'foo2');
        is($self->bar('bar2'), 'bar2');
        is($self->bar(), 'bar2');
        is($self->{bar}, 'bar2');
    }
}

# dynamic
sub test3 {
    my $self = shift;
    for my $name (qw(foo bar)) {
        is($self->$name("${name}3"), "${name}3");
        is($self->$name(), "${name}3");
        is($self->{$name}, "${name}3");
    }
}

# dynamic with a twist: the second sub isn't a Class::XSAccessor XSUB.
# this should a) disable the optimization for the two entersub calls
# b) switch foo over to non-optimizing mode and c) (of course) still
# work as expected for foo and baz. the bar accessor should still be optimizing
sub test4 {
    my $self = shift;
    for my $name (qw(foo baz)) {
        is($self->$name("${name}4"), "${name}4");
        is($self->$name(), "${name}4");
        is($self->{$name}, "${name}4");
    }
    is($self->bar('bar4'), 'bar4');
    is($self->bar(), 'bar4');
    is($self->{bar}, 'bar4');
}

# call the methods as subs to see how this impacts the optimized entersub
sub test5 {
    my $self = shift;
    is(foo($self, 'foo5'), 'foo5');
    is(foo($self), 'foo5');
    is($self->{foo}, 'foo5');
    is(bar($self, 'bar5'), 'bar5');
    is(bar($self), 'bar5');
    is($self->{bar}, 'bar5');
}

# call the methods as subs with & - this sets a flag in the entersub's op_private
# XXX: these are passed in as GVs rather than CVs
sub test6 {
    my $self = shift;
    is(&foo($self, 'foo6'), 'foo6');
    is(&foo($self), 'foo6');
    is($self->{foo}, 'foo6');
    is(&bar($self, 'bar6'), 'bar6');
    is(bar($self), 'bar6');
    is($self->{bar}, 'bar6');
}

# call the methods with $self->can('accessor_name') to see how this impacts the optimized entersub.
# XXX: methods found by can() are passed in as GVs, which the optimization doesn't currently
# support
sub test7 {
    my $self = shift;
    is($self->can('foo')->($self, 'foo7'), 'foo7');
    is($self->can('foo')->($self), 'foo7');
    is($self->{foo}, 'foo7');
    is($self->can('bar')->($self, 'bar7'), 'bar7');
    is($self->can('bar')->($self), 'bar7');
    is($self->{bar}, 'bar7');
}

$SIG{__WARN__} = sub {
    my $warning = join '', @_;

    if ($warning =~ m{^cxah: (.+)\n$}) {
        push @WARNINGS, $1;
    } else {
        warn @_; # from perldoc -f warn: __WARN__ hooks are not called from inside one.
    }
};

my $self = main->new();

$self->test1();
$self->test2();
$self->test3();
$self->test4();
$self->test5();
$self->test6();
$self->test7();

$self->test1();
$self->test2();
$self->test3();
$self->test4();
$self->test5();
$self->test6();
$self->test7();

# The best way to verify this test is to a) look for lines above that should disable
# optimization and search for "disabling" below (e.g. ack disabling t/08hash_entersub.t),
# and/or b) look for "disabling" below and make sure it matches the behaviours above

my $WANT = [
    'accessor: inside test_init at t/08hash_entersub.t line 31.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 31.',
    'accessor: inside test_init at t/08hash_entersub.t line 32.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 32.',
    'accessor: inside test_init at t/08hash_entersub.t line 34.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 34.',
    'accessor: inside test_init at t/08hash_entersub.t line 35.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 35.',
    'accessor: inside test_init at t/08hash_entersub.t line 43.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 43.',
    'accessor: inside test_init at t/08hash_entersub.t line 44.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 44.',
    'accessor: inside test_init at t/08hash_entersub.t line 46.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 46.',
    'accessor: inside test_init at t/08hash_entersub.t line 47.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 47.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 43.',
    'accessor: inside test at t/08hash_entersub.t line 43.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 44.',
    'accessor: inside test at t/08hash_entersub.t line 44.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 46.',
    'accessor: inside test at t/08hash_entersub.t line 46.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 47.',
    'accessor: inside test at t/08hash_entersub.t line 47.',
    'accessor: inside test_init at t/08hash_entersub.t line 56.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 56.',
    'accessor: inside test_init at t/08hash_entersub.t line 57.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 57.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 56.',
    'accessor: inside test at t/08hash_entersub.t line 56.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 57.',
    'accessor: inside test at t/08hash_entersub.t line 57.',
    'accessor: inside test_init at t/08hash_entersub.t line 69.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 69.',
    'accessor: inside test_init at t/08hash_entersub.t line 70.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 70.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 69.',
    'entersub: disabling optimization: CV is not test at t/08hash_entersub.t line 69.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 70.',
    'entersub: disabling optimization: CV is not test at t/08hash_entersub.t line 70.',
    'accessor: inside test_init at t/08hash_entersub.t line 73.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 73.',
    'accessor: inside test_init at t/08hash_entersub.t line 74.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 74.',
    'accessor: inside test_init at t/08hash_entersub.t line 81.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 81.',
    'accessor: inside test_init at t/08hash_entersub.t line 82.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 82.',
    'accessor: inside test_init at t/08hash_entersub.t line 84.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 84.',
    'accessor: inside test_init at t/08hash_entersub.t line 85.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 85.',
    'accessor: inside test_init at t/08hash_entersub.t line 93.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 93.',
    'accessor: inside test_init at t/08hash_entersub.t line 94.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 94.',
    'accessor: inside test_init at t/08hash_entersub.t line 96.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 96.',
    'accessor: inside test_init at t/08hash_entersub.t line 97.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 97.',
    'accessor: inside test_init at t/08hash_entersub.t line 106.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 106.',
    'accessor: inside test_init at t/08hash_entersub.t line 107.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 107.',
    'accessor: inside test_init at t/08hash_entersub.t line 109.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 109.',
    'accessor: inside test_init at t/08hash_entersub.t line 110.',
    'accessor: op_spare: 000',
    'accessor: optimizing entersub at t/08hash_entersub.t line 110.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 31.',
    'accessor: inside test at t/08hash_entersub.t line 31.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 32.',
    'accessor: inside test at t/08hash_entersub.t line 32.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 34.',
    'accessor: inside test at t/08hash_entersub.t line 34.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 35.',
    'accessor: inside test at t/08hash_entersub.t line 35.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 43.',
    'accessor: inside test at t/08hash_entersub.t line 43.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 44.',
    'accessor: inside test at t/08hash_entersub.t line 44.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 46.',
    'accessor: inside test at t/08hash_entersub.t line 46.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 47.',
    'accessor: inside test at t/08hash_entersub.t line 47.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 43.',
    'accessor: inside test at t/08hash_entersub.t line 43.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 44.',
    'accessor: inside test at t/08hash_entersub.t line 44.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 46.',
    'accessor: inside test at t/08hash_entersub.t line 46.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 47.',
    'accessor: inside test at t/08hash_entersub.t line 47.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 56.',
    'accessor: inside test at t/08hash_entersub.t line 56.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 57.',
    'accessor: inside test at t/08hash_entersub.t line 57.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 56.',
    'accessor: inside test at t/08hash_entersub.t line 56.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 57.',
    'accessor: inside test at t/08hash_entersub.t line 57.',
    'accessor: inside test_init at t/08hash_entersub.t line 69.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 69.',
    'accessor: inside test_init at t/08hash_entersub.t line 70.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 70.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 73.',
    'accessor: inside test at t/08hash_entersub.t line 73.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 74.',
    'accessor: inside test at t/08hash_entersub.t line 74.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 81.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 81.',
    'accessor: inside test_init at t/08hash_entersub.t line 81.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 81.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 82.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 82.',
    'accessor: inside test_init at t/08hash_entersub.t line 82.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 82.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 84.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 84.',
    'accessor: inside test_init at t/08hash_entersub.t line 84.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 84.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 85.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 85.',
    'accessor: inside test_init at t/08hash_entersub.t line 85.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 85.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 93.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 93.',
    'accessor: inside test_init at t/08hash_entersub.t line 93.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 93.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 94.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 94.',
    'accessor: inside test_init at t/08hash_entersub.t line 94.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 94.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 96.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 96.',
    'accessor: inside test_init at t/08hash_entersub.t line 96.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 96.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 97.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 97.',
    'accessor: inside test_init at t/08hash_entersub.t line 97.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 97.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 106.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 106.',
    'accessor: inside test_init at t/08hash_entersub.t line 106.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 106.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 107.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 107.',
    'accessor: inside test_init at t/08hash_entersub.t line 107.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 107.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 109.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 109.',
    'accessor: inside test_init at t/08hash_entersub.t line 109.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 109.',
    'entersub: inside optimized entersub at t/08hash_entersub.t line 110.',
    'entersub: disabling optimization: sv is not a CV at t/08hash_entersub.t line 110.',
    'accessor: inside test_init at t/08hash_entersub.t line 110.',
    'accessor: op_spare: 001',
    'accessor: entersub optimization has been disabled at t/08hash_entersub.t line 110.'
];

is_deeply(\@WARNINGS, $WANT);

# print STDERR Dumper(\@WARNINGS), $/;
