#
# Copyright 2020 Centreon (http://www.centreon.com/)
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

package eventhandler::cachethq::mode::incident;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use Digest::MD5 qw(md5_hex);

use JSON::XS;


my $CACHET_STATUS_INVESTIGATING = 1;
my $CACHET_STATUS_IDENTIFIED = 2;
my $CACHET_STATUS_WATCHING = 3;
my $CACHET_STATUS_FIXED = 4;

my $CACHET_COMPONENT_STATUS_OPERATIONAL = 1;
my $CACHET_COMPONENT_STATUS_PERFORMANCE_ISSUES =2;
my $CACHET_COMPONENT_STATUS_PARTIAL_OUTAGE =3;
my $CACHET_COMPONENT_STATUS_MAJOR_OUTAGE = 4;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        "hostname:s"            => { name => 'hostname', default => '127.0.0.1'},
        "port:i"                => { name => 'port', default => 8000 },
        "proto:s"               => { name => 'proto', default => 'http' },
        "urlpath:s"             => { name => 'url_path', default => "/api/v1" },
        "cachet-component-id:s" => { name => 'cachet_component_id' },
        "cachet-application:s"  => { name => 'cachet_application',default => "Centreon" },
        "cachet-token:s"        => { name => 'cachet_token' },
        "cachet-prefix:s"       => { name => 'cachet_prefix' },
        "cachet-notify:s"       => { name => 'cachet_notify',default=>0 },
        "host-name:s"           => { name => 'host_name' },
        "host-state:s"          => { name => 'host_state' },
        "host-state-type:s"     => { name => 'host_state_type' },
        "host-output:s"         => { name => 'host_output' },
        "service-description:s" => { name => 'service_description' },
        "service-state:s"       => { name => 'service_state' },
        "service-state-type:s"  => { name => 'service_state_type' },
        "service-output:s"      => { name => 'service_output' },
        "timeout:s"             => { name => 'timeout' },
    });
    $self->{cache} = centreon::plugins::statefile->new(%options);
    $self->{http} = centreon::plugins::http->new(%options);
    return $self;
}

sub check_options {
    my ($self, %options) = @_;

    $self->SUPER::init(%options);
    if (!defined($self->{option_results}->{cachet_application})) {
        $self->{output}->add_option_msg(short_msg => "You need to set --cachet-application option");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{cachet_token})) {
        $self->{output}->add_option_msg(short_msg => "You need to set --cachet-token option");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{cachet_component_id})) {
        $self->{output}->add_option_msg(short_msg => "You need to set --cachet-component-id option");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{cachet_token})) {
        $self->{output}->add_option_msg(short_msg => "You need to set --cachet-token option");
        $self->{output}->option_exit();
    }
    # if (((!defined($self->{option_results}->{host_name})) || ($self->{option_results}->{host_name} eq '')) ||
    #     ((!defined($self->{option_results}->{service_description})) || ($self->{option_results}->{service_description} eq ''))) 
    #     {
    #     $self->{output}->add_option_msg(short_msg => "You need to specify --host-name or --service-description option.");
    #     $self->{output}->option_exit();
    # }
    # if (!defined($self->{option_results}->{host_state} || $self->{option_results}->{service_state}) eq '') {
    #     $self->{output}->add_option_msg(short_msg => "You need to specify --host-state or --service-state option.");
    #     $self->{output}->option_exit();
    # }
    # if (!defined($self->{option_results}->{host_state_type} || $self->{option_results}->{service_state_type}) eq '') {
    #     $self->{output}->add_option_msg(short_msg => "You need to specify --host-state-type or --host-state-type option.");
    #     $self->{output}->option_exit();
    # }
    $self->{http}->set_options(%{$self->{option_results}});
    $self->{cache}->check_options(option_results => $self->{option_results});

}

sub host_notify {
  my ($self, %options) = @_;
 $self->{notify_name} = $self->{option_results}->{host_name};
        $self->{notify_message} = $self->{option_results}->{host_output};
    if  (($self->{option_results}->{host_state} eq 'DOWN') && ($self->{option_results}->{host_state_type} eq 'SOFT')) {
        $self->{notify_status} = $CACHET_STATUS_WATCHING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_PARTIAL_OUTAGE;
    } elsif  (($self->{option_results}->{host_state} eq 'DOWN') && ($self->{option_results}->{host_state_type} eq 'HARD')) {
        $self->{notify_status} = $CACHET_STATUS_INVESTIGATING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_MAJOR_OUTAGE;
    } elsif  (($self->{option_results}->{host_state} eq 'UP') && ($self->{option_results}->{host_state_type} eq 'SOFT')) {
        $self->{notify_status} = $CACHET_STATUS_WATCHING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_OPERATIONAL;
    } elsif  (($self->{option_results}->{host_state} eq 'UP') && ($self->{option_results}->{host_state_type} eq 'HARD')) {
        $self->{notify_status} = $CACHET_STATUS_FIXED;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_OPERATIONAL;
    } 
  }

sub service_notify {
    my ($self, %options) = @_;

        $self->{notify_name} = $self->{option_results}->{host_name}." - ".$self->{option_results}->{service_description};
        $self->{notify_message} = $self->{option_results}->{service_output};
    if (($self->{option_results}->{service_state} eq 'WARNING') && ($self->{option_results}->{service_state_type} eq 'SOFT')){
        $self->{notify_status} = $CACHET_STATUS_WATCHING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_PERFORMANCE_ISSUES;
    } elsif  (($self->{option_results}->{service_state} eq 'WARNING') && ($self->{option_results}->{service_state_type} eq 'HARD')) {
        $self->{notify_status} = $CACHET_STATUS_INVESTIGATING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_PERFORMANCE_ISSUES;
    }elsif  (($self->{option_results}->{service_state} eq 'CRITICAL') && ($self->{option_results}->{service_state_type} eq 'SOFT')) {
        $self->{notify_status} = $CACHET_STATUS_WATCHING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_PARTIAL_OUTAGE;
    } elsif  (($self->{option_results}->{service_state} eq 'CRITICAL') && ($self->{option_results}->{service_state_type} eq 'HARD')) {
        $self->{notify_status} = $CACHET_STATUS_INVESTIGATING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_MAJOR_OUTAGE;
    } elsif  (($self->{option_results}->{service_state} eq 'OK') && ($self->{option_results}->{service_state_type} eq 'SOFT')) {
        $self->{notify_status} = $CACHET_STATUS_WATCHING;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_OPERATIONAL;
    } elsif  (($self->{option_results}->{service_state} eq 'OK') && ($self->{option_results}->{service_state_type} eq 'HARD')) {
        $self->{notify_status} = $CACHET_STATUS_FIXED;
        $self->{notify_component_status} = $CACHET_COMPONENT_STATUS_OPERATIONAL;
    } 
}

sub set_payload {
    my ($self, %options) = @_;

    if (defined($self->{option_results}->{service_description}) && $self->{option_results}->{service_description} ne '') {
        $self->service_notify();
    }
     else {
        $self->host_notify();
    }
}

sub format_payload {
    my ($self, %options) = @_;

    my $json = JSON::XS->new->utf8;


    my $payload = { name =>$self->{notify_name},
                    message => $self->{notify_message},
                    status =>  0+$self->{notify_status},
                    visible => 1,
                    component_id => 0+$self->{option_results}->{cachet_component_id},
                    component_status => $self->{notify_component_status},
                    notify => $self->{option_results}->{cachet_notify}
                    };
                    
    eval {
        $self->{payload_str} = $json->encode($payload);
    };
print $self->{payload_str};
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot encode json request");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;

    $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
    $self->{http}->add_header(key => 'X-Cachet-Token', value => $self->{option_results}->{cachet_token});
    $self->{http}->add_header(key => 'X-Cachet-Application', value => $self->{option_results}->{cachet_application});

    my $url_path = $self->{option_results}->{url_path}."/incidents";
    my $verb = 'POST';
    
    my $has_incident_declared = $self->{cache} ->read(statefile => 'cachehq_incident_' . md5_hex($self->{option_results}->{hostname}) . '_' . md5_hex(defined($self->{option_results}->{service_description})?$self->{option_results}->{service_description}:'HOST'));
    my $incident_id = $self->{cache} ->get(name => 'id');
    if (defined($incident_id)) {
        my $check_url_path_ = $url_path.'/'.$incident_id;
        my $check_verb = 'GET';
        my $check_response = $self->{http}->request(url_path => $check_url_path_, method => $check_verb,unknown_status=>'%{http_code}>=500');
        
        my $check_decoded = JSON::XS->new->utf8->decode($check_response);
          
         if (defined($check_decoded->{data}->{id})) {
         $verb = 'PUT';
         $url_path  = $url_path.'/'.$incident_id;
        }
    }

    $self->set_payload();
    $self->format_payload();
    my $response = $self->{http}->request(url_path => $url_path,
                                          method => $verb, query_form_post => $self->{payload_str},unknown_status=>'%{http_code}>=500');

    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($response);
    };
    if ($@) {
        $self->{output}->output_add(long_msg => $response, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }
    if (!defined($decoded->{data}->{id})) {
        $self->{output}->output_add(long_msg => $decoded, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Error sending incident");
        $self->{output}->option_exit();
    }
    $self->{cache}->write(data => {id=>$decoded->{data}->{id}});
   
    $self->{output}->output_add(short_msg => 'Incident ID : ' . $decoded->{data}->{id});

    $self->{output}->display(force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Manage EventHandler with CachetHQ API.

=over 6

=item B<--hostname>

CachetHQ server FQDN or IP (Default : localhost)

=item B<--port>

CachetHQ server Port (Default : 8000)

=item B<--proto>

Protocol used for accessing CachetHQ (Default : http)

=item B<--cachet-token>

CachetHQ API Token generated from the Dashboard (Mandatory)

=item B<--cachet-application>

Identification of Application Calling to CachetHQ (Default : Centreon)

=item B<--cachet-notify>

Notify CachetHQ Subscribers about the incident.

=item B<--host-state>

Specify host server state for the incident.

=item B<--host-state-type>

Specify host server state type for the incident.

=item B<--host-output>

Specify host server output message for the incident.

=item B<--service-description>

Specify service description name for the incident.

=item B<--service-state>

Specify service state for the incident.

=item B<--service-state-type>

Specify service state type for the incident.

=item B<--service-output>

Specify service output message for the incident.

=item B<--timeout>

Threshold for HTTP timeout.

=back

=cut
