#
# Copyright 2018 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package cloud::flexibleengine::custom::api;

use strict;
use warnings;
use DateTime;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use URI::Encode;
use Digest::MD5 qw(md5_hex);
use Date::Parse qw(str2time);
use Data::Dumper;


sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    if (!defined($options{output})) {
        print "Class Custom: Need to specify 'output' argument.\n";
        exit 3;
    }
    if (!defined($options{options})) {
        $options{output}->add_option_msg(short_msg => "Class Custom: Need to specify 'options' argument.");
        $options{output}->option_exit();
    }

    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "domain-id:s"           => { name => 'domain_id' },
                                    "project-id:s"          => { name => 'project_id' },
                                    "username:s"            => { name => 'username' },
                                    "password:s"            => { name => 'password' },
                                    "region:s"              => { name => 'region' },
                                    "proxyurl:s"            => { name => 'proxyurl' },
                                    "proxypac:s"            => { name => 'proxypac' },
                                    "timeout:s"             => { name => 'timeout' },
                                    "ssl-opt:s@"            => { name => 'ssl_opt' },
                                });
    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http} = centreon::plugins::http->new(%options);
    $self->{cache} = centreon::plugins::statefile->new(%options);
    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;


    $self->{domain_id} = (defined($self->{option_results}->{domain_id})) ? $self->{option_results}->{domain_id} : undef;
    $self->{project_id} = (defined($self->{option_results}->{project_id})) ? $self->{option_results}->{project_id} : undef;
    $self->{username} = (defined($self->{option_results}->{username})) ? $self->{option_results}->{username} : undef;
    $self->{password} = (defined($self->{option_results}->{password})) ? $self->{option_results}->{password} : undef;
    $self->{region} = (defined($self->{option_results}->{region})) ? $self->{option_results}->{region} : undef;


    if (!defined($self->{domain_id}) || $self->{domain_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --domain-id option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{project_id}) || $self->{project_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --project-id option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{username}) || $self->{username} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --username option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{password}) || $self->{password} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --password option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{region}) || $self->{region} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --region option.");
        $self->{output}->option_exit();
    }

    $self->{iam_endpoint} = "https://iam.".$self->{region}.".prod-cloud-ocb.orange-business.com";

    $self->{cache}->check_options(option_results => $self->{option_results});

    $self->{http}->set_options(%{$self->{option_results}});
}

sub get_access_token {
    my ($self, %options) = @_;

    my $has_cache_file = $options{statefile}->read(statefile => 'flexible_engine_api_' . md5_hex($self->{domain_id}) . '_' . md5_hex($self->{project_id}). '_' . md5_hex($self->{username}));
    my $expires_on = $options{statefile}->get(name => 'expires_on');
    my $access_token = $options{statefile}->get(name => 'access_token');

    if ($has_cache_file == 0 || !defined($access_token) || (($expires_on - time()) < 10)) {

        my $json_request = { auth=>{identity=>{methods=>["password"],
                             password=>{
                               user=>{
                                 name=>$self->{username},
                                 password => $self->{password},
                                 domain=>{
                                   id=>$self->{domain_id}
                                   },
                                 }
                               },
                             },

                             scope=>{
                               project=>{
                                 id=>$self->{project_id}
                               },
                              },
                             },
                           };
        my $encoded;
        eval {
          $encoded = encode_json($json_request);
        };
        $self->settings();

        my $content = $self->{http}->request(method => 'POST', query_form_post => $encoded,
                                             full_url => $self->{iam_endpoint} . '/v3/auth/tokens',
                                             hostname => '');

        my $decoded;
        eval {
            $decoded = JSON::XS->new->utf8->decode($content);
        };
        if ($@) {
            $self->{output}->output_add(long_msg => $content, debug => 1);
            $self->{output}->add_option_msg(short_msg => "Cannot decode json response");
            $self->{output}->option_exit();
        }
        if (defined($decoded->{error})) {
            $self->{output}->output_add(long_msg => "Error message : " . $decoded->{error_description}, debug => 1);
            $self->{output}->add_option_msg(short_msg => "Login endpoint API return error code '" . $decoded->{error} . "' (add --debug option for detailed message)");
        }
         if (!defined($self->{http}->get_header(name=>'x-subject-token'))) {
            $self->{output}->output_add(long_msg => "Unable to Retrieve Token");
            $self->{output}->option_exit();

            
        }
        $access_token = $self->{http}->get_header(name=>'x-subject-token');
        my $datas = { last_timestamp => time(),access_token=> $access_token, expires_on => int(str2time($decoded->{token}{expires_at})) };
        $options{statefile}->write(data => $datas);

    }

    return $access_token;
}

sub get_region {
    my ($self, %options) = @_;

    return $self->{option_results}->{region};
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{timeout} = $self->{timeout};
    $self->{option_results}->{proxyurl} = $self->{proxyurl};
    $self->{option_results}->{ssl_opt} = $self->{ssl_opt};
}

sub settings {
    my ($self, %options) = @_;

    $self->build_options_for_httplib();
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
    $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    if (defined($self->{access_token})) {
        $self->{http}->add_header(key => 'X-Auth-Token', value =>  $self->{access_token});
    }
    $self->{http}->set_options(%{$self->{option_results}});
}


sub request_api {
    my ($self, %options) = @_;

    if (!defined($self->{access_token})) {

        $self->{access_token} = $self->get_access_token(statefile => $self->{cache});

    }
    $self->settings();
    my $content = $self->{http}->request(%options);

    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($content);
    };
    if ($@) {
        $self->{output}->output_add(long_msg => $content, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }
    if (defined($decoded->{error})) {
        $self->{output}->output_add(long_msg => "Error message : " . $decoded->{error}->{message}, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Endpoint API return error code '" . $decoded->{error}->{code} . "' (add --debug option for detailed message)");
        $self->{output}->option_exit();
    }

    return $decoded;
}
sub internal_api_list_servers {
    my ($self, %options) = @_;
    $self->{ecs_endpoint} = 'https://ecs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $servers_list = $self->request_api(method => 'GET', full_url =>$self->{ecs_endpoint}.'/v2/'.$self->{project_id}.'/servers',hostname => '');
    return $servers_list->{servers};
}

sub internal_api_detail_servers {
    my ($self, %options) = @_;
    $self->{ecs_endpoint} = 'https://ecs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $server_detail = $self->request_api(method => 'GET', full_url =>$self->{ecs_endpoint}.'/v2/'.$self->{project_id}.'/servers/'.$options{server_id},hostname => '');
    return $server_detail->{server};
}


sub api_list_servers {
  my ($self, %options) = @_;

    my $servers = [];
    my $list_servers = $self->internal_api_list_servers();
    foreach  my $server (@{$list_servers}) {
        my $server_detail = $self->internal_api_detail_servers(server_id=>$server->{id});
        push @{$servers} , {
            Id => $server_detail->{id},
            State => $server_detail->{status},
            AvailabilityZone => $server_detail->{'OS-EXT-AZ:availability_zone'},
            Name => $server_detail->{name},
            
        };
    }

    return $servers;
}


1;


=head1 MODE

Flexible Engine

=over 6

=item B<--domain-id>

Set Flexible Engine Domain ID.

=item B<--project-id>

Set Flexible Engine Project ID.

=item B<--username>

Set Flexible Engine Username.

=item B<--password>

Set Flexible Engine Password.

=item B<--region>

Set Flexible Engine region

=item B<--proxyurl>

Proxy URL if any.

=item B<--proxypac>

Proxy pac file (can be an url or local file).

=item B<--timeout>

Threshold for HTTP timeout.

=item B<--ssl-opt>

Set SSL Options (--ssl-opt="SSL_version => TLSv1" --ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE").

=back

=cut
