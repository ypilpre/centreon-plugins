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

package notification::flexibleengine::smn::mode::alert;

use base qw(centreon::plugins::mode);

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
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                {
                                    "domain-id:s"           => { name => 'domain_id' },
                                    "project-id:s"          => { name => 'project_id' },
                                    "username:s"            => { name => 'username' },
                                    "password:s"            => { name => 'password' },
                                    "region:s"              => { name => 'region' },
                                    "topic-urn:s"           => { name => 'topic_urn' },
                                    "host-name:s"           => { name => 'host_name' },
                                    "host-state:s"          => { name => 'host_state' },
                                    "host-output:s"         => { name => 'host_output' },
                                    "service-description:s" => { name => 'service_description' },
                                    "service-state:s"       => { name => 'service_state' },
                                    "service-output:s"      => { name => 'service_output' },
                                    "notification-type:s"   => { name => 'notification_type' },
                                    "graph-url:s"           => { name => 'graph_url' },
                                    "link-url:s"            => { name => 'link_url' },
                                    "centreon-url:s"        => { name => 'centreon_url' },
                                    "centreon-token:s"      => { name => 'centreon_token' },
                                    "proxyurl:s"            => { name => 'proxyurl' },
                                    "proxypac:s"            => { name => 'proxypac' },
                                    "timeout:s"             => { name => 'timeout' },
                                    "ssl-opt:s@"            => { name => 'ssl_opt' },
                                });

    $self->{http} = centreon::plugins::http->new(output => $self->{output});
    $self->{cache} = centreon::plugins::statefile->new(%options);
    return $self;
}

sub check_options {
    my ($self, %options) = @_;

    $self->SUPER::init(%options);


    if (!defined($self->{option_results}->{host_name}) || $self->{option_results}->{host_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --host-name option.");
        $self->{output}->option_exit();
    }

    $self->{domain_id} = (defined($self->{option_results}->{domain_id})) ? $self->{option_results}->{domain_id} : undef;
    $self->{project_id} = (defined($self->{option_results}->{project_id})) ? $self->{option_results}->{project_id} : undef;
    $self->{username} = (defined($self->{option_results}->{username})) ? $self->{option_results}->{username} : undef;
    $self->{password} = (defined($self->{option_results}->{password})) ? $self->{option_results}->{password} : undef;
    $self->{region} = (defined($self->{option_results}->{region})) ? $self->{option_results}->{region} : undef;
    $self->{topic_urn} = (defined($self->{option_results}->{topic_urn})) ? $self->{option_results}->{topic_urn} : undef;

    if (!defined($self->{option_results}->{topic_urn})) {
        $self->{output}->add_option_msg(short_msg => "You need to set --topic-urn option");
        $self->{output}->option_exit();
    }

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
    $self->{smn_endpoint} = "https://smn.".$self->{region}.".prod-cloud-ocb.orange-business.com";

    $self->{cache}->check_options(option_results => $self->{option_results});


    foreach (('graph_url', 'link_url')) {
        if (defined($self->{option_results}->{$_})) {
            $self->{option_results}->{$_} =~ s/%\{(.*?)\}/\$self->{option_results}->{$1}/g;
            eval "\$self->{option_results}->{\$_} = \"$self->{option_results}->{$_}\"";
        }
    }

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
            $self->{output}->option_exit();
        }
        my $headers = $self->{http}->get_header();
        $access_token = $headers->header('x-subject-token');

        my $datas = { last_timestamp => time(),access_token=> $access_token, expires_on => int(str2time($decoded->{token}{expires_at})) };
        $options{statefile}->write(data => $datas);

    }

    return $access_token;
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{timeout} = $self->{timeout};
    $self->{option_results}->{proxyurl} = $self->{proxyurl};
    $self->{option_results}->{ssl_opt} = $self->{ssl_opt};
    $self->{option_results}->{warning_status} = '';
    $self->{option_results}->{critical_status} = '';
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

sub host_message {
  my ($self, %options) = @_;

    $self->{subject} .= " Host <i>" . $self->{option_results}->{host_name} . "</i>";

    if (defined($self->{option_results}->{host_state}) && $self->{option_results}->{host_state} ne '') {
        $self->{subject} .= ' is <b>' . $self->{option_results}->{host_state} . '</b>';
    } else {
        $self->{subject} .= ' alert';
    }
    if (defined($self->{option_results}->{host_output}) && $self->{option_results}->{host_output} ne '') {
        $self->{message} .= "\n ".  $self->{option_results}->{host_output};
    }

    if (defined($self->{option_results}->{link_url}) && $self->{option_results}->{link_url} ne '') {
        $self->{message} .= "\n <a href=\"" . $self->{option_results}->{link_url} . "\">Link</a>";
    }
}

sub service_message {
    my ($self, %options) = @_;


    $self->{header} .= " Host <i>" . $self->{option_results}->{host_name} . "</i> | Service <i> " . $self->{option_results}->{service_description} . "</i>";

    if (defined($self->{option_results}->{service_state}) && $self->{option_results}->{service_state} ne '') {
        $self->{subject} .= ' is <b>' . $self->{option_results}->{service_state} . '</b>';
    } else {
        $self->{subject} .= ' alert';
    }
    if (defined($self->{option_results}->{service_output}) && $self->{option_results}->{service_output} ne '') {
        $self->{message} .= "\n ".  $self->{option_results}->{service_output};
    }
    if (defined($self->{option_results}->{link_url}) && $self->{option_results}->{link_url} ne '') {
        $self->{message} .= "\n <a href=\"" . $self->{option_results}->{link_url} . "\">Link</a>";
    }
    if (defined($self->{option_results}->{graph_url}) && $self->{option_results}->{graph_url} ne '') {
        $self->{message} .= "\n <a href=\"" . $self->{option_results}->{graph_url} . "\">Graph</a>";
    }
}

sub set_payload {
    my ($self, %options) = @_;

    if (defined($self->{option_results}->{service_description}) && $self->{option_results}->{service_description} ne '') {
        $self->service_message();
    } else {
        $self->host_message();
    }
}

sub format_payload {
    my ($self, %options) = @_;

    my $json = JSON::XS->new->utf8;

    my $payload = { subject =>$self->{subject},
                    message_structure => $self->{message} };
    eval {
        $self->{payload_str} = $json->encode($payload);
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot encode json request");
        $self->{output}->option_exit();
    }
}

sub fe_smn_set_url {
    my ($self, %options) = @_;

    my $url =   $self->{smn_endpoint}."/v2/".$self->{project_id}."/notifications/topics/".$self->{topic_urn}."/publish";
    print $url;
    return $url;
}


sub run {
    my ($self, %options) = @_;


    $self->set_payload();
    $self->format_payload();


    my $full_url = $self->fe_smn_set_url(%options);

    my $response = $self->request_api(method => 'POST', query_form_post => $self->{payload_str}, full_url => $full_url, hostname => '');


    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($response);
    };
    if ($@) {
        $self->{output}->output_add(long_msg => $response, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }
    if (!defined($decoded->{message_id})) {
        $self->{output}->output_add(long_msg => $decoded, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Error sending message");
        $self->{output}->option_exit();
    }

    $self->{output}->output_add(short_msg => 'Message ID : ' . $decoded->{message_id});
    $self->{output}->display(force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;


=head1 MODE

Send message with Flexible Engine SNM API.

=over 6

=item B<--domain-id>

Set Flexible Engine Domain ID.

=item B<--project-id>

Set Flexible Engine project ID.

=item B<--username>

Set Flexible Engine Username.

=item B<--password>

Set Flexible Engine Password.

=item B<--region>

Set Flexible Engine region

=item B<--toptic-urn>

URN of Topic used by SNM

=item B<--proxyurl>

Proxy URL if any.

=item B<--proxypac>

Proxy pac file (can be an url or local file).

=item B<--host-state>

Specify host server state for the alert.

=item B<--host-output>

Specify host server output message for the alert.

=item B<--host-name>

Specify host server name for the alert (Required).

=item B<--notification-type>

Specify Notification Type (used for Icon display).

=item B<--service-description>

Specify service description name for the alert.

=item B<--service-state>

Specify service state for the alert.

=item B<--service-output>

Specify service output message for the alert.

=item B<--centreon-url>

Specify the centreon url macro (could be used in link-url and graph-url option).

=item B<--centreon-token>

Specify the centreon token for autologin macro (could be used in link-url and graph-url option).

=item B<--graph-url>

Specify the graph url (Example: %{centreon_url}/include/views/graphs/generateGraphs/generateImage.php?username=myuser&token=%{centreon_token}&hostname=%{host_name}&service=%{service_description}).

=item B<--link-url>

Specify the link url (Example: %{centreon_url}/main.php?p=20201&o=svc&host_search=%{host_name}&svc_search=%{service_description})

=item B<--timeout>

Threshold for HTTP timeout.

=item B<--ssl-opt>

Set SSL Options (--ssl-opt="SSL_version => TLSv1" --ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE").

=back

=cut
