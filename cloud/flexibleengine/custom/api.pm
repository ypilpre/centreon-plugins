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
                                    'frame:s'               => { name => 'frame' },
                                    'period:s'              => { name => 'period' },
                                    'zeroed'                => { name => 'zeroed' },
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

sub get_user_token {
    my ($self, %options) = @_;

    my $has_cache_file = $options{statefile}->read(statefile => 'flexible_engine_api_' . md5_hex($self->{domain_id}) . '_' . md5_hex($self->{project_id}). '_' . md5_hex($self->{username}));
    my $expires_on = $options{statefile}->get(name => 'expires_on');
    my $user_token = $options{statefile}->get(name => 'user_token');

    if ($has_cache_file == 0 || !defined($user_token) || (($expires_on - time()) < 10)) {

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
        $self->http_settings();

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
        $user_token = $self->{http}->get_header(name=>'x-subject-token');
        my $datas = { last_timestamp => time(),user_token=> $user_token ,expires_on => int(str2time($decoded->{token}{expires_at})) };
        $options{statefile}->write(data => $datas);

    }

    return $user_token;
}

sub get_access_secret_token{
 my ($self, %options) = @_;

    my $has_cache_file = $options{statefile}->read(statefile => 'flexible_engine_api_assk_' . md5_hex($self->{domain_id}) . '_' . md5_hex($self->{project_id}). '_' . md5_hex($self->{username}));
    my $expires_on = $options{statefile}->get(name => 'expires_on');
    my $access_key = $options{statefile}->get(name => 'access_key');
    my $secret_key = $options{statefile}->get(name => 'secret_key');
    if (!defined($self->{user_token})) {

        $self->{user_token} = $self->get_user_token(statefile => $self->{cache});

    }    if ($has_cache_file == 0 || !defined($access_key) || !defined($secret_key) ||(($expires_on - time()) < 10)) {


       $self->{http}->add_header(key => 'Content-Type', value => 'application/json;charset=utf8');

        my $json_request = { auth=>{identity=>{methods=>["token"],
                             token=>{
                                 id=>$self->{user_token} ,
                                 duration =>86400}
                                 }
                               
                             }
                           };
        my $encoded;
        eval {
          $encoded = encode_json($json_request);
        };
        $self->http_settings();
        $self->{http}->add_header(key => 'Content-Type', value => 'application/json;charset=utf8');
        my $content = $self->{http}->request(method => 'POST', query_form_post => $encoded,
                                             full_url => $self->{iam_endpoint} . '/v3.0/OS-CREDENTIAL/securitytokens',
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
         if (!defined($decoded->{credential}->{access})) {
            $self->{output}->output_add(long_msg => "Unable to Retrieve AS/SK");
            $self->{output}->option_exit();
         }
        $access_key = $decoded->{credential}->{access};
        $secret_key = $decoded->{credential}->{secret};

        my $datas = { last_timestamp => time(),access_key=> $access_key , secret_key=>$secret_key,expires_on => int(str2time($decoded->{credential}->{expires_at})) };
        $options{statefile}->write(data => $datas);
    }   

    return {access_key=>$access_key,secret_key=>$secret_key}

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

sub http_settings {
    my ($self, %options) = @_;

    $self->build_options_for_httplib();
  $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
    if (defined($self->{user_token})) {
        $self->{http}->add_header(key => 'X-Auth-Token', value =>  $self->{user_token});
    }
    $self->{http}->set_options(%{$self->{option_results}});
}


sub request_api {
    my ($self, %options) = @_;

    if (!defined($self->{user_token})) {

        $self->{user_token} = $self->get_user_token(statefile => $self->{cache});

    }
    $self->http_settings();
    
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


sub api_list_ecs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $servers_list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/servers/detail',hostname => '');
    return $servers_list;
}

sub api_list_ecs_tags {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    $self->{http}->add_header(key => 'X-OpenStack-Nova-API-Version', value => '2.26');
    my $ecs_tags_list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/servers/'.$options{server_id}.'/tags',hostname => '');
    my $ecs_tags;
    foreach my $tag (@{$ecs_tags_list->{tags}}) {
        my @tag_content=split /=/,$tag;
        $ecs_tags .= " ".join(',',@tag_content);
    }
    return $ecs_tags;
}

sub api_list_ecs_with_tag {
  my ($self, %options) = @_;

    my $ecs_with_tag ;
    my $list_servers = $self->api_list_ecs();
    foreach  my $server (@{$list_servers->{servers}}) {
        my $server_tags = $self->api_list_ecs_tags(server_id=>$server->{id});        
        push @{$ecs_with_tag} , {
            id => $server->{id},
            status => $server->{status},
            availabilityzone => $server->{'OS-EXT-AZ:availability_zone'},
            tags => $server_tags
        }; 
    }
    return $ecs_with_tag;
}

sub api_list_vpc {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v1/'.$self->{project_id}.'/vpcs',hostname => '');
    return $list;
}


sub api_list_rds {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://rds.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v3/'.$self->{project_id}.'/instances',hostname => '');
    return $list;
}

sub api_list_rds_nodes {
  my ($self, %options) = @_;

    my $nodes = [];
    my $list_rds = $self->api_list_rds();
    foreach my $instance (@{$list_rds->{instances}}){
        foreach  my $node (@{$instance->{nodes}}) {
            push @{$nodes} , {
                id => $node->{id},
                status => $node->{status},
                availability_zone =>  $node->{availability_zone},
                role =>  $node->{role},
                name => $node->{name},
                instance => $instance->{name},
            
             };
        }
    }

    return $nodes;
}


sub api_list_css {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://css.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/clusters',hostname => '');
    return $list;
}

sub api_list_evs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://evs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2/'.$self->{project_id}.'/os-vendor-volumes/detail',hostname => '');
    return $list;
}

sub api_list_nat {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://nat.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2.0/nat_gateways',hostname => '');
    return $list;
}

sub api_list_elb {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://elb.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2.0/lbaas/loadbalancers',hostname => '');
    return $list;
}

sub api_list_clb {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://elb.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/elbaas/loadbalancers',hostname => '');
    return $list;
}

sub api_list_dcs{
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://dcs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/instances',hostname => '');
    return $list;
}

sub api_list_eip{
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v1/'.$self->{project_id}.'/publicips',hostname => '');
    return $list;
}

sub api_list_sfs{
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://sfs.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/v2/'.$self->{project_id}.'/shares/detail',hostname => '');
    return $list;
}

sub api_list_cce{
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://cce.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $list = $self->request_api(method => 'GET', full_url =>$self->{endpoint}.'/api/v3/projects/'.$self->{project_id}.'/clusters',hostname => '');
    return $list;
}





sub api_get_servers_status {
  my ($self, %options) = @_;

    my $servers = [];
    my $list_servers = $self->internal_api_list_servers();
    foreach  my $server (@{$list_servers}) {
        my $server_detail = $self->internal_api_detail_server(server_id=>$server->{id});
        push @{$servers} , {
            Id => $server_detail->{id},
            Status => $server_detail->{status},
            State => $server_detail->{'OS-EXT-STS:vm_state'},
            Name => $server_detail->{name},
            
        };
    }

    return $servers;
}

sub api_cloudeye_list_metrics {
    my ($self, %options) = @_;
    $self->{ces_endpoint} = 'https://ces.'.$self->{region}.'.prod-cloud-ocb.orange-business.com';
    my $uri= $self->{ces_endpoint} .'/V1.0/'.$self->{project_id}.'/metrics?';
    if (defined($options{namespace})){
    $uri = $uri."namespace=".$options{namespace};
    }
    if (defined($options{metric})){
    $uri = $uri."&metric_name=".$options{metric};
    }
    my $metrics_list = $self->request_api(method => 'GET', full_url =>$uri,hostname => '');
    return $metrics_list->{metrics};
}

sub internal_api_cloudeyes_get_metric {
     my ($self, %options) = @_;
    $self->{ces_endpoint} = 'https://ces.'.$self->{region}.'.prod-cloud-ocb.orange-business.com'.'/V1.0/'.$self->{project_id}.'/batch-query-metric-data';
    my $ces_query = {};
    $ces_query->{from} = $options{start_time};
    $ces_query->{to} = $options{end_time};
    $ces_query->{period} = ''.$options{period};
    $ces_query->{filter} = $options{filter};
    $ces_query->{metrics} = [];
    foreach my $metric (@{$options{metrics}}){
        my $metric_detail = {};
        $metric_detail->{metric_name} = $metric;
        $metric_detail->{namespace} = $options{namespace};
        $metric_detail->{dimensions} =[];
        foreach my $dimension (@{$options{dimensions}}){
            push @{$metric_detail->{dimensions}},{name=>$dimension->{name},value=>$dimension->{value}};
        }
         push @{$ces_query->{metrics}},$metric_detail;
    }
    my $encoded;
        eval {
          $encoded = encode_json($ces_query);
        };
    $self->http_settings();
    my $metrics_result = $self->request_api(method => 'POST', query_form_post =>$encoded, full_url =>$self->{ces_endpoint},hostname => '');

    return $metrics_result;
}

sub api_cloudeyes_get_metric {
    my ($self, %options) = @_;

    my $metric_results = {};
    my $start_time = (DateTime->now->subtract(seconds => $options{frame})->epoch())*1000;
    my $end_time = (DateTime->now->epoch())*1000;

    foreach my $metric_name (@{$options{metrics}}) {

    my $raw_results = $self->internal_api_cloudeyes_get_metric(%options, metric_name => $metric_name,dimension=>$options{dimensions},
            start_time => $start_time, end_time => $end_time,period=>$options{period},filter=>$options{filter});
        
        foreach my $metric (@{$raw_results->{metrics}}) {

           $metric_results->{$metric->{metric_name}} = { points => 0 };
           foreach my $point (@{$metric->{datapoints}}) {
             if (defined($point->{average})) {
                    $metric_results->{$metric->{metric_name}}->{average} = 0 if (!defined($metric_results->{$metric->{metric_name}}->{average}));
                    $metric_results->{$metric->{metric_name}}->{average} += $point->{average};
             }
             if (defined($point->{min})) {
                  $metric_results->{$metric->{metric_name}}->{min} = $point->{min}
                     if (!defined($metric_results->{$metric->{metric_name}}->{min}) || $point->{min} < $metric_results->{$metric->{metric_name}}->{min});
             }
             if (defined($point->{max})) {
                $metric_results->{$metric->{metric_name}}->{max} = $point->{max}
                    if (!defined($metric_results->{$metric->{metric_name}}->{max}) || $point->{max} > $metric_results->{$metric->{metric_name}}->{max});
             }
            if (defined($point->{sum})) {
                $metric_results->{$metric->{metric_name}}->{sum} = 0 if (!defined($metric_results->{$metric->{metric_name}}->{sum}));
                $metric_results->{$metric->{metric_name}}->{sum} += $point->{sum};
            }
             if (defined($point->{variance})) {
                $metric_results->{$metric->{metric_name}}->{variance} = 0 if (!defined($metric_results->{$metric->{metric_name}}->{variance}));
                $metric_results->{$metric->{metric_name}}->{variance} += $point->{variance};
            }

            $metric_results->{$metric->{metric_name}}->{points}++;
        }

        if (defined($metric_results->{$metric->{metric_name}}->{average})) {
            $metric_results->{$metric->{metric_name}}->{average} /= $metric_results->{$metric->{metric_name}}->{points};
        }
    }
    }
    return $metric_results;
}

sub api_discovery {
    my ($self, %options) = @_;
    my $api_result = {};
    if ($options{service} eq 'ecs'){
        $api_result = $self->api_list_full_servers(%options)
    }
    if ($options{service} eq 'vpc'){
        $api_result = $self->api_list_vpc(%options)
    }
    if ($options{service} eq 'nat'){
        $api_result = $self->api_list_nat(%options)
    }
    if ($options{service} eq 'elb'){
        $api_result = $self->api_list_elb(%options)
    }
    if ($options{service} eq 'clb'){
        $api_result = $self->api_list_clb(%options)
    }
    if ($options{service} eq 'dcs'){
        $api_result = $self->api_list_dcs(%options)
    }
    if ($options{service} eq 'eip'){
        $api_result = $self->api_list_eip(%options)
    }
    if ($options{service} eq 'sfs'){
        $api_result = $self->api_list_sfs(%options)
    }
    if ($options{service} eq 'evs'){
        $api_result = $self->api_list_evs(%options)
    }
    if ($options{service} eq 'rds'){
        $api_result = $self->api_list_rds(%options)
    }
    if ($options{service} eq 'cce'){
        $api_result = $self->api_list_cce(%options)
    }
    return $api_result;
}

sub discovery {
    my ($self, %options) = @_;

    my $raw_results =  $self->api_discovery(%options);

    return $raw_results;
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

=item B<--zeroed>

Set metrics value to 0 if none. Usefull when Monitor
does not return value when not defined.

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
