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

package notification::o365::mode::alert;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::http;
use JSON;

my %o365_color_host = (
    up => '42f56f',
    down => 'f21616',
    unreachable => 'f21616',
);
my %o365_color_service = (
    ok => '42f56f',
    warning => 'f59042',
    critical => 'f21616',
    unknown => '757575',
);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
            {
            "o365-webhook:s"           => { name => 'o365_webhook' },
            "host-name:s"           => { name => 'host_name' },
            "host-state:s"          => { name => 'host_state' },
            "host-output:s"         => { name => 'host_output' },
            "service-description:s" => { name => 'service_description' },
            "service-state:s"       => { name => 'service_state' },
            "service-output:s"      => { name => 'service_output' },
            "graph-url:s"           => { name => 'graph_url' },
            "link-url:s"            => { name => 'link_url' },
            "centreon-url:s"        => { name => 'centreon_url' },
            "centreon-token:s"      => { name => 'centreon_token' },
            "credentials"           => { name => 'credentials' },
            "basic"                 => { name => 'basic' },
            "ntlm"                  => { name => 'ntlm' },
            "username:s"            => { name => 'username' },
            "password:s"            => { name => 'password' },
            "proxyurl:s"            => { name => 'proxyurl' },
            "proxypac:s"            => { name => 'proxypac' },
            "timeout:s"             => { name => 'timeout' },
            "ssl-opt:s@"            => { name => 'ssl_opt' },
            });
    $self->{http} = centreon::plugins::http->new(%options);
    $self->{body_sections} = []; 
    $self->{potiential_action} = [];

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{o365_webhook}) || $self->{option_results}->{o365_webhook} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --o365-webhook option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{option_results}->{host_name}) || $self->{option_results}->{host_name} eq '') {
        $self->{output}->add_option_msg(short_msg => "You need to specify --host-name option.");
        $self->{output}->option_exit();
    }
    
    foreach (('graph_url', 'link_url')) {
        if (defined($self->{option_results}->{$_})) {
            $self->{option_results}->{$_} =~ s/%\{(.*?)\}/\$self->{option_results}->{$1}/g;
            eval "\$self->{option_results}->{\$_} = \"$self->{option_results}->{$_}\"";
        }
    }

    $self->{http}->set_options(%{$self->{option_results}}, hostname => 'dummy');
}

sub format_payload {
    my ($self, %options) = @_;
    
    my $json = JSON->new;
    my $payload = { '@type' => "MessageCard",
	                '@context'=> "https://schema.org/extensions",
                    'Summary' => 'Centreon Alert',
                     themecolor => $self->{color},
                    sections =>  $self->{body_sections},
                    potentialAction =>  $self->{links}
                    };
    eval {
        $self->{payload_str} = $json->encode($payload);
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response");
        $self->{output}->option_exit();
    }
}

sub host_message {
    my ($self, %options) = @_;
    
    my $url_host = $self->{option_results}->{host_name};
    
    if (defined($self->{option_results}->{host_state}) && $self->{option_results}->{host_state} ne '') {
       push @{$self->{body_sections}}, {'activityTitle'=>"Host " . $url_host.' is ' . $self->{option_results}->{host_state}};
        if (defined($o365_color_host{lc($self->{option_results}->{host_state})})) {
           
            $self->{color} = $o365_color_host{lc($self->{option_results}->{host_state})};
        }
    }
    if (defined($self->{option_results}->{link_url}) && $self->{option_results}->{link_url} ne '') {
        push @{$self->{links}},  {'@type'=> "OpenUri",'name'=>"Details",'targets'=>[{'os'=>'default','uri'=>$self->{option_results}->{link_url}}]};
    }
      if (defined($self->{option_results}->{host_output}) && $self->{option_results}->{host_output} ne '') {
        push @{$self->{body_sections}}, {'text'=> $self->{option_results}->{host_output}};
    }
  
}

sub service_message {
    my ($self, %options) = @_;
    
    my $url_service = "Host: " . $self->{option_results}->{host_name} . " - Service " . $self->{option_results}->{service_description};

    
    if (defined($self->{option_results}->{service_state}) && $self->{option_results}->{service_state} ne '') {
               push @{$self->{body_sections}}, {'activityTitle'=>$url_service.' is ' . $self->{option_results}->{service_state}};

        if (defined($o365_color_service{lc($self->{option_results}->{service_state})})) {
            $self->{color} = $o365_color_service{lc($self->{option_results}->{service_state})};
        }
    
}
    if (defined($self->{option_results}->{link_url}) && $self->{option_results}->{link_url} ne '') {
         push @{$self->{links}},    {'@type'=> "OpenUri",'name'=>"Details",'targets'=>[{'os'=>'default','uri'=>$self->{option_results}->{link_url}}]};
    }
    
    if (defined($self->{option_results}->{service_output}) && $self->{option_results}->{service_output} ne '') {
        push @{$self->{body_sections}}, {'text'=> $self->{option_results}->{service_output}};
    }
    
    if (defined($self->{option_results}->{graph_url}) && $self->{option_results}->{graph_url} ne '') {
        push @{$self->{links}},  {'@type'=> "OpenUri",'name'=>"Graphs",'targets'=>[{'os'=>'default','uri'=>$self->{option_results}->{graph_url}}]};
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

sub run {
    my ($self, %options) = @_;

    $self->set_payload();
    $self->format_payload();
     $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
    my $response = $self->{http}->request(full_url => $self->{option_results}->{o365_webhook}, 
                                          method => 'POST', 
                                          query_form_post => $self->{payload_str});
    
    $self->{output}->output_add(short_msg => 'Office 365 response: ' . $response);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Send o365 alerts.

Example for a host:
centreon_plugins.pl --plugin=notification::o365::plugin --mode=alert --o365-webhook='https://' --host-name='srvi-clus-win' --host-state='DOWN' --host-output='test output' --priority='High' --zone='Production' --centreon-url='https://centreon.test.com/centreon/' --link-url='%{centreon_url}/main.php?p=20202&o=svc&host_search=%{host_name}'

Example for a service:
centreon_plugins.pl --plugin=notification::o365::plugin --mode=alert --o365-webhook='https://' --host-name='srvi-clus-win' --service-description='Ping' --service-state='WARNING' --service-output='CRITICAL - 10.50.1.78: rta nan, lost 100%' --priority='High' --zone='Production' --centreon-url='https://ces.merethis.net/centreon/' --link-url='%{centreon_url}/main.php?p=20201&o=svc&host_search=%{host_name}&svc_search=%{service_description}' --centreon-token='LxTQxFbLU6' --graph-url='%{centreon_url}/include/views/graphs/generateGraphs/generateImage.php?username=myuser&token=%{centreon_token}&hostname=%{host_name}&service=%{service_description}'

=over 8

=item B<--o365-webhook>

Specify o365 webhook (Required).

=item B<--host-name>

Specify host server name for the alert (Required).

=item B<--host-state>

Specify host server state for the alert.

=item B<--host-output>

Specify host server output message for the alert.

=item B<--service-description>

Specify service description name for the alert.

=item B<--service-state>

Specify service state for the alert.

=item B<--service-output>

Specify service output message for the alert.

=item B<--priority>

Specify the priority message.

=item B<--centreon-url>

Specify the centreon url macro (could be used in link-url and graph-url option).

=item B<--centreon-token>

Specify the centreon token for autologin macro (could be used in link-url and graph-url option).

=item B<--graph-url>

Specify the graph url (Example: %{centreon_url}/include/views/graphs/generateGraphs/generateImage.php?username=myuser&token=%{centreon_token}&hostname=%{host_name}&service=%{service_description}).

=item B<--link-url>

Specify the link url (Example: %{centreon_url}/main.php?p=20201&o=svc&host_search=%{host_name}&svc_search=%{service_description})

=item B<--proxyurl>

Proxy URL

=item B<--proxypac>

Proxy pac file (can be an url or local file)

=item B<--credentials>

Specify this option if you access webpage with authentication

=item B<--username>

Specify username for authentication (Mandatory if --credentials is specified)

=item B<--password>

Specify password for authentication (Mandatory if --credentials is specified)

=item B<--basic>

Specify this option if you access webpage over basic authentication and don't want a '401 UNAUTHORIZED' error to be logged on your webserver.

Specify this option if you access webpage over hidden basic authentication or you'll get a '404 NOT FOUND' error.

(Use with --credentials)

=item B<--timeout>

Threshold for HTTP timeout (Default: 5)

=item B<--ssl-opt>

Set SSL Options (--ssl-opt="SSL_version => TLSv1" --ssl-opt="SSL_verify_mode => SSL_VERIFY_NONE").

=back

=cut
