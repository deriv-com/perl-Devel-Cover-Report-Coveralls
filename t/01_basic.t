use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use Devel::Cover::Report::Coveralls;

my $normal_endpoint = 'https://coveralls.io/api/v1/jobs';
my $endpoint_stem = '/api/v1/jobs';

subtest 'get_config (travis)' => sub {
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    local $ENV{TRAVIS_PULL_REQUEST} = 'false';
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
    ok !exists $got->{service_pull_request},'not a pull request';
    local $ENV{TRAVIS_PULL_REQUEST} = '456';
    ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_pull_request},'456','config pull request';
    is $endpoint, $normal_endpoint, 'config endpoint';
};

subtest 'get_config extra env (travis)' => sub {
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{TRAVIS}        = 'true';
    local $ENV{TRAVIS_JOB_ID} = 100000;
    my $diff_endpoint = 'http://localhost';
    local $ENV{COVERALLS_ENDPOINT} = $diff_endpoint;
    local $ENV{COVERALLS_FLAG_NAME} = 'Unit';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_job_id}, 100000, 'config service_job_id';
    is $got->{service_name}, 'travis-ci', 'config service_name';
    is $got->{flag_name}, 'Unit', 'config flag_name';
    is $endpoint, $diff_endpoint . $endpoint_stem, 'new endpoint';
};

subtest 'get_config github' => sub {
    local $ENV{TRAVIS}          = undef; # reset on travis
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_ACTIONS}  = 1;
    local $ENV{GITHUB_SHA}      = '123456789';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'github-actions', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
    is $endpoint, $normal_endpoint;
};

subtest 'get_config github actions improved' => sub {
    local $ENV{TRAVIS} = undef;
    local $ENV{DRONE} = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = undef;
    local $ENV{GITHUB_TOKEN} = 'abcdef';
    local $ENV{GITHUB_RUN_ID} = '123456789';
    local $ENV{CIRCLECI} = undef;
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();
    is $got->{service_name}, 'github', 'config service_name';
    is $got->{service_job_id}, '123456789', 'config service_job_id';
};

subtest 'get_config azure' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{GITHUB_REF}     = undef; # reset on github
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{SYSTEM_TEAMFOUNDATIONSERVERURI} = 1;
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{BUILD_SOURCEBRANCHNAME} = 'feature';
    local $ENV{BUILD_BUILDID} = '123456789';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'azure-pipelines', 'config service_name';
    is $got->{service_number}, '123456789', 'config service_number';
    is $endpoint, $normal_endpoint;

    $got = Devel::Cover::Report::Coveralls::get_git_info();
    is $got->{branch}, 'feature', 'git branch';
};

subtest 'get_config drone' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{GITHUB_REF}     = undef; # reset on github
    local $ENV{CIRCLECI}       = undef;
    local $ENV{DRONE_PULL_REQUEST} = '666';
    local $ENV{DRONE_BUILD_NUMBER} = '123';
    local $ENV{DRONE} = "drone";
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';

    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'drone', 'config service_name';
    is $got->{service_number}, '123', 'config service_number';
    is $got->{service_pull_request}, '666', 'config service_pull_request';
    is $endpoint, $normal_endpoint;
};

subtest 'get_config local' => sub {
    local $ENV{TRAVIS}         = undef; # reset on travis
    local $ENV{GITHUB_ACTIONS} = undef; # reset on github
    local $ENV{DRONE}           = undef; # reset on drone
    local $ENV{COVERALLS_REPO_TOKEN} = 'abcdef';
    local $ENV{GITHUB_TOKEN} = undef;
    local $ENV{CIRCLECI} = undef;
    
    my ($got, $endpoint) = Devel::Cover::Report::Coveralls::get_config();

    is $got->{service_name}, 'coveralls-perl', 'config service_name';
    is $got->{service_event_type}, 'manual', 'config service_event_type';
    is $endpoint, $normal_endpoint;
};

subtest 'get_source' => sub {
    my $source = {
        name => "$FindBin::Bin/example.pl",
        source => <<EOS,
#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

print "hello, world";
EOS
        coverage => [undef, undef, undef, undef, undef, 0]
    };

    is_deeply Devel::Cover::Report::Coveralls::get_source("$FindBin::Bin/example.pl",
        sub { $_[0] == 6 ? 0 : undef } ), $source, 'source';
};

subtest 'get_source from sub-directory' => sub {
    my $file_path = "$FindBin::Bin/example.pl";
    my $source = Devel::Cover::Report::Coveralls::get_source($file_path, sub { $_[0] == 6 ? 0 : undef } );
    is $source->{name}, $file_path, 'Check path when the source file is not in a sub-directory';

    local $ENV{CHANGED_DIR} = 'project';
    my $source = Devel::Cover::Report::Coveralls::get_source($file_path, sub { $_[0] == 6 ? 0 : undef } );
    is $source->{name}, "project/$file_path", 'Check path when the source file is in a sub-directory';
};

done_testing;
