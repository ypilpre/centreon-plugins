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

package cloud::flexibleengine::custom::aksk;

use strict;
use warnings;
use DateTime;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use URI::Encode qw(uri_encode uri_decode);;
use Digest::MD5 qw(md5_hex);
use Date::Parse qw(str2time);
#Specific module for AK/SK Authentication
use POSIX 'strftime';
use Digest::SHA qw(hmac_sha256_hex sha256_hex hmac_sha256);
use URI::Split qw(uri_split uri_join);
use URI::Escape qw(uri_escape uri_unescape);
#Specific for OBS/S3 Access 
use XML::Simple;

my %obc_service_map = (
   'ecs' => {'type' => 'compute'},
   'iam' => {'type' => 'identity'},
   'cce' => {'type' => 'ccev2.0'},
   'evs' => {'type' => 'volumev2'},
   'ces' => {'type' => 'cesv1'},
   'rds' => {'type' => 'rdsv3'},
   'sfs' => {'type' => 'share'},
   'css' => {'type' => 'css'},
   'workspace' => {'type' => 'workspace'},
   'dds' => {'type' => 'ddsv3'},
   'elb' => {'type' => 'network'},
   'vpc' => {'type' => 'vpc'},
   'css' => {'type' => 'css'},
   'oss' => {'type' => 's3'},
   'dcs' => {'type' => 'dcsv1'},



);

my $default_endpoint_domain = "prod-cloud-ocb.orange-business.com";
my $sdk_signature_algorithm='SDK-HMAC-SHA256';
my $aws_signature_algorithm='AWS4-HMAC-SHA256';


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
                                    "project-id:s"          => { name => 'project_id' },
                                    "domain-id:s"           => { name => 'domain_id' },
                                    "access-key:s"          => { name => 'access_key' },
                                    "secret-key:s"          => { name => 'secret_key' },
                                    "endpoint-domain:s"     => { name => 'endpoint_domain' },
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


    $self->{project_id} = (defined($self->{option_results}->{project_id})) ? $self->{option_results}->{project_id} : undef;
    $self->{access_key} = (defined($self->{option_results}->{access_key})) ? $self->{option_results}->{access_key} : undef;
    $self->{secret_key} = (defined($self->{option_results}->{secret_key})) ? $self->{option_results}->{secret_key} : undef;
    $self->{region} = (defined($self->{option_results}->{region})) ? $self->{option_results}->{region} : undef;
    $self->{endpoint_domain} = (defined($self->{option_results}->{endpoint_domain})) ? $self->{option_results}->{endpoint_domain} : $default_endpoint_domain;


    if (!defined($self->{project_id}) || $self->{project_id} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --project-id option.");
        $self->{output}->option_exit();
    }


    if (!defined($self->{access_key}) || $self->{access_key} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --access-key option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{secret_key}) || $self->{secret_key} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --secret-key option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{region}) || $self->{region} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --region option.");
        $self->{output}->option_exit();
    }

    $self->{iam_endpoint} = "https://iam.".$self->{region}.".".$self->{endpoint_domain};

    $self->{cache}->check_options(option_results => $self->{option_results});

    $self->{http}->set_options(%{$self->{option_results}});
}

sub _zulu_time {
    my $epochtime = time();
    my @datetime = gmtime($epochtime);
    return (strftime('%Y%m%dT%H%M%SZ',@datetime),strftime('%Y%m%d',@datetime),strftime('%a, %d %B %Y %H:%M:%S GMT',@datetime));
}


sub _sort_query_string {
        my ($self, %options) = @_;
        return '' unless $options{query};
        my @params;
        for my $param ( split /&/, $options{query} ) {
                my ( $key, $value ) = 
                        map { tr/+/ /; uri_escape( uri_unescape( $_ ) ) } # escape all non-unreserved chars
                        split /=/, $param;
                push @params, [$key, (defined $value ? $value : '')];
        }
        return join '&',
                map { join '=', @$_ }
                sort { ( $a->[0] cmp $b->[0] ) || ( $a->[1] cmp $b->[1] ) }
                @params;
}

sub _sdk_signing_key {
    my ($self, %options) = @_;
    my $ksecret = "SDK".$self->{secret_key};
    my $kdate = hmac_sha256($options{date},$ksecret);
    my $kregion = hmac_sha256($options{region},$kdate);
    my $kservice = hmac_sha256($options{service},$kregion);
    my $kapp = hmac_sha256("sdk_request",$kservice);
    return  $kapp;
}


sub _sdk_signature_request {
      my ($self, %options) = @_;
      my $canonicalrequest;
      my $string_to_sign;
      my $signature;
      my $uri = URI->new($options{full_url});
      my $host = $uri->host();
      my $query = $uri->query();
      my $path = $uri->path();
      my $service = $obc_service_map{$options{service}}->{type};
      (my $zuludatetime, my $zuludate, my $expirationtime) = $self->_zulu_time();
      my $scope =$zuludate."/".lc$self->{option_results}->{region}."/".$obc_service_map{$options{service}}->{type}."/sdk_request";
      $self->{http}->add_header(key => 'Host', value => $host);
      $self->{http}->add_header(key => 'X-Sdk-Date', value =>$zuludatetime );
      $canonicalrequest= $options{method}."\n";
      $canonicalrequest.=  $path."/\n";
      $canonicalrequest.=  $self->_sort_query_string(query=>$query);
      $canonicalrequest.="\n";
      my @sorted_map=();
      foreach ( sort {lc $a cmp lc $b} keys %{$self->{http}->{add_headers}}){
          $canonicalrequest.=lc ($_).":".$self->{http}->{add_headers}{$_} ."\n";
          push @sorted_map, $_;
      }
      my $signed_headers=lc join(';' , @sorted_map);
      $canonicalrequest.="\n";
      $canonicalrequest.=lc $signed_headers."\n";
      if (defined($options{payload})) {
      $canonicalrequest.=lc sha256_hex($options{payload});
      }else
      {
      $canonicalrequest.=lc sha256_hex("");
      }
      $string_to_sign.=$sdk_signature_algorithm."\n";
      $string_to_sign.=$zuludatetime."\n";
      $string_to_sign.=$scope."\n";
      $string_to_sign.=lc sha256_hex($canonicalrequest);
      $signature=hmac_sha256_hex($string_to_sign,$self->_sdk_signing_key(date=>$zuludate,region=>lc$self->{option_results}->{region},service=>$service));
      $self->{http}->add_header(key => 'Content-Type', value =>'application/json');
      $self->{http}->add_header(key => 'X-OpenStack-Nova-API-Version', value => '2.26');
      $self->{http}->add_header(key => 'Accept', value =>'application/json');
      $self->{http}->add_header(key => 'Authorization', value =>
      $sdk_signature_algorithm." Credential=".$self->{access_key}."/".$scope.", SignedHeaders=".$signed_headers.", Signature=".$signature );

}

sub _aws_signing_key {
    my ($self, %options) = @_;
    my $ksecret = "AWS4".$self->{secret_key};
    my $kdate = hmac_sha256($options{date},$ksecret);
    my $kregion = hmac_sha256($options{region},$kdate);
    my $kservice = hmac_sha256("s3",$kregion);
    my $kapp = hmac_sha256("aws4_request",$kservice);
    return  $kapp;
}






sub _aws_signature_request {
      my ($self, %options) = @_;
      my $canonicalrequest;
      my $string_to_sign;
      my $signature;
      my $payload_hash;
       if (defined($options{payload})) {
           $payload_hash=lc sha256_hex($options{payload});
        }else{
           $payload_hash=lc sha256_hex("");
        }
      my $uri = URI->new($options{full_url});
      my $host = $uri->host();
      my $query = $uri->query();
      my $path = $uri->path();
      my $service = "$obc_service_map{$options{service}}->{type}";
      (my $zuludatetime, my $zuludate, my $zulu_extended) = $self->_zulu_time();
      my $scope =$zuludate."/".lc$self->{option_results}->{region}."/".$obc_service_map{$options{service}}->{type}."/aws4_request";
      $self->{http}->add_header(key => 'Host', value => $host);
      $self->{http}->add_header(key => 'x-Amz-Content-Sha256', value => $payload_hash );
      $self->{http}->add_header(key => 'X-Amz-Date', value =>$zuludatetime );
      $canonicalrequest= $options{method}."\n";
      $canonicalrequest.=  $path."/\n";
      $canonicalrequest.=  $self->_sort_query_string(query=>$query);
      $canonicalrequest.= "\n";
      my @sorted_map=();
      foreach ( sort {lc $a cmp lc $b} keys %{$self->{http}->{add_headers}}){
          $canonicalrequest.=lc ($_).":".$self->{http}->{add_headers}{$_} ."\n";
          push @sorted_map, $_;
      }
      my $signed_headers=lc join(';' , @sorted_map);
      $canonicalrequest.="\n";
      $canonicalrequest.=lc $signed_headers."\n";
      $canonicalrequest.=$payload_hash;
      $string_to_sign.=$aws_signature_algorithm."\n";
      $string_to_sign.=$zuludatetime."\n";
      $string_to_sign.=$scope."\n";
      $string_to_sign.=lc sha256_hex($canonicalrequest);
      $signature=hmac_sha256_hex($string_to_sign,$self->_aws_signing_key(date=>$zuludate,region=>lc$self->{option_results}->{region},service=>$service));
      $self->{http}->add_header(key => 'Authorization', value =>
      $aws_signature_algorithm." Credential=".$self->{access_key}."/".$scope.", SignedHeaders=".$signed_headers.", Signature=".$signature );

}

sub request_aws {
    my ($self, %options) = @_;


    $self->http_settings();
    $self->_aws_signature_request(method=>$options{method},payload=>$options{query_form_post},service=>$options{service},full_url=>$options{full_url});
    my $content = $self->{http}->request(%options);
    my @bucket;
    my $decoded;
    if ($options{method} ne 'HEAD') {

    if ($self->{http}->get_code() != 200) {
        eval {
            $decoded = XMLin($content, ForceArray => [], KeyAttr => []);
       };
       if ($@) {
           $self->{output}->output_add(long_msg => $content, debug => 1);
          $self->{output}->add_option_msg(short_msg => "Cannot decode xml response: $@");
           $self->{output}->option_exit();
       }
       if (defined($decoded->{error})) {
           $self->{output}->output_add(long_msg => "Error message : " . $decoded->{error}->{message}, debug => 1);
           $self->{output}->add_option_msg(short_msg => "Endpoint API return error code '" . $decoded->{error}->{code} . "' (add --debug option for detailed message)");
           $self->{output}->option_exit();
       }
    }else{
        eval {
            $decoded = XMLin($content, ForceArray => [], KeyAttr => []);
       };
       if ($@) {
        $self->{output}->output_add(long_msg => $content, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Cannot decode xml response: $@");
        $self->{output}->option_exit();
    }
    }
    }
    else{
        my $storage_class=$self->{http}->get_header(name=>'x-default-storage-class');
        my $storage_region= $self->{http}->get_header(name=>'x-amz-bucket-region');
        $self->{http}->{add_headers}=undef;
        $options{full_url}=undef;
        return ($storage_class,$storage_region);

    }
    $self->{http}->{add_headers}=undef;
    $options{full_url}=undef;

    #Clear HTTP Headers before creating a new signed request
    return $decoded;


}

sub request_api {
    my ($self, %options) = @_;


    $self->http_settings();
    $self->_sdk_signature_request(method=>$options{method},payload=>$options{query_form_post},service=>$options{service},full_url=>$options{full_url});
    
    my $content = $self->{http}->request(%options);
    if ($self->{http}->get_code() != 200) {
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
    }

    my $decoded;
        eval {
            $decoded = JSON::XS->new->utf8->decode($content);
       };
       if ($@) {
        $self->{output}->output_add(long_msg => $content, debug => 1);
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }
    #Clear HTTP Headers before creating a new signed request
    $self->{http}->{add_headers}=undef;
    return $decoded;
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
    $self->{http}->set_options(%{$self->{option_results}});
}




sub api_list_ecs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.".".$self->{endpoint_domain};
    my $servers_list = $self->request_api(method => 'GET', service=>'ecs', full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/servers/detail',hostname => '');
    return $servers_list;
}

sub api_list_ecs_detail {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.".".$self->{endpoint_domain};
    my $server = $self->request_api(method => 'GET', service=>'ecs', full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/servers/'.$options{server_id},hostname => '');
    return $server;
}



sub api_list_ecs_flavor {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.".".$self->{endpoint_domain};
    my $flavor_list = $self->request_api(method => 'GET', service=>'ecs', full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/flavors/detail',hostname => '');
    return $flavor_list;
}

sub api_list_ecs_quota {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.".".$self->{endpoint_domain};
    my $quota_list = $self->request_api(method => 'GET',service=>'ecs', full_url =>$self->{endpoint}.'/v1/'.$self->{project_id}.'/cloudservers/limits',hostname => '');
    return $quota_list->{absolute};
}

sub api_list_ecs_tags {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ecs.'.$self->{region}.".".$self->{endpoint_domain};
    my $ecs_tags_list = $self->request_api(method => 'GET', service=>'ecs',full_url =>$self->{endpoint}.'/v2.1/'.$self->{project_id}.'/servers/'.$options{server_id}.'/tags',hostname => '');
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
    $self->{endpoint} = 'https://vpc.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'vpc',full_url =>$self->{endpoint}.'/v1/'.$self->{project_id}.'/vpcs',hostname => '');
    return $list;
}


sub api_list_rds {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://rds.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'rds', service=>'rds',full_url =>$self->{endpoint}.'/v3/'.$self->{project_id}.'/instances',hostname => '');
    return $list;
}

sub api_list_rds_detail {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://rds.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'rds',full_url =>$self->{endpoint}.'/v3/'.$self->{project_id}.'/instances?id='.$options{instance_id},hostname => '');
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

sub api_list_dds_nodes {
  my ($self, %options) = @_;

    my $nodes = [];
    my $list_rds = $self->api_list_dds();
    foreach my $instance (@{$list_rds->{instances}}){
        foreach  my $group (@{$instance->{groups}}) {
            foreach my $node (@{$group->{nodes}}){
                push @{$nodes} , {
                    id => $node->{id},
                    status => $node->{status},
                    availability_zone =>  $node->{availability_zone},
                    role =>  $node->{role},
                    name => $node->{name},
                    private_ip => $node->{private_ip},
                    public_ip => $node->{public_ip},
                    port => $instance->{port},
                    mode => $instance->{mode},
                    ssl => 0+$instance->{ssl},
                    engine => $instance->{engine},
                    instance => $instance->{name},
                    instance_id => $instance->{id},
                    spec => $node->{spec_code},
                    type => $group->{type},
                };
            }
        }
    }

    return $nodes;
}


sub api_list_css {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://css.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'css',full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/clusters',hostname => '');
    return $list;
}

sub api_list_evs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://evs.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'evs',full_url =>$self->{endpoint}.'/v2/'.$self->{project_id}.'/os-vendor-volumes/detail',hostname => '');
    return $list;
}

sub api_list_evs_quota {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://evs.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'evs', full_url =>$self->{endpoint}.'/v3/'.$self->{project_id}.'/os-quota-sets/'.$self->{project_id}.'?usage=True',hostname => '');
    return $list->{quota_set};
}

sub api_list_nat {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://nat.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'nat', full_url =>$self->{endpoint}.'/v2.0/nat_gateways',hostname => '');
    return $list;
}

sub api_list_elb {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'elb',full_url =>$self->{endpoint}.'/v2.0/lbaas/loadbalancers',hostname => '');
    return $list;
}

sub api_list_elb_detail {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.".".$self->{endpoint_domain};
    my $server = $self->request_api(method => 'GET', service=>'elb',full_url =>$self->{endpoint}.'/v2.0/lbaas/loadbalancers/'.$options{elb_id},hostname => '');
    return $server;
}

sub api_list_elb_quota {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.".".$self->{endpoint_domain};
    my $quota_list = $self->request_api(method => 'GET', service=>'elb',full_url =>$self->{endpoint}.'/v1.0/elbaas/quotas',hostname => '');
    return $quota_list->{quotas};
}

sub api_list_clb {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://elb.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'clb', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/elbaas/loadbalancers',hostname => '');
    return $list;
}

sub api_list_dcs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://dcs.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'dcs', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/instances',hostname => '');
    return $list;
}

sub api_list_dcs_detail {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://dcs.'.$self->{region}.".".$self->{endpoint_domain};
    my $detail = $self->request_api(method => 'GET',service=>'dcs', full_url =>$self->{endpoint}.'/v1.0/'.$self->{project_id}.'/instances/'.$options{instance_id},hostname => '');
    return $detail;
}

sub api_list_eip {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://vpc.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'vpc', full_url =>$self->{endpoint}.'/v1/'.$self->{project_id}.'/publicips',hostname => '');
    return $list;
}

sub api_list_sfs {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://sfs.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'sfs',full_url =>$self->{endpoint}.'/v2/'.$self->{project_id}.'/shares/detail',hostname => '');
    return $list;
}

sub api_list_cce {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://cce.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET', service=>'cce',full_url =>$self->{endpoint}.'/api/v3/projects/'.$self->{project_id}.'/clusters',hostname => '');
    return $list;
}

sub api_list_dds {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://dds.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'dds', full_url =>$self->{endpoint}.'/v3/'.$self->{project_id}.'/instances',hostname => '');
    return $list;
}


sub api_list_ces_alarms {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://ces.'.$self->{region}.".".$self->{endpoint_domain};
    my $list = $self->request_api(method => 'GET',service=>'ces', full_url =>$self->{endpoint}.'/V1.0/'.$self->{project_id}.'/alarms',hostname => '');
    return $list;
}


sub api_cloudeye_list_metrics {
    my ($self, %options) = @_;
    $self->{ces_endpoint} = 'https://ces.'.$self->{region}.".".$self->{endpoint_domain};
    my $uri= $self->{ces_endpoint} .'/V1.0/'.$self->{project_id}.'/metrics';
    if (defined($options{namespace})){
    $uri = $uri."?namespace=".$options{namespace};
    }
    if (defined($options{metric}) && defined($options{namespace})){
    $uri = $uri."&metric_name=".$options{metric};
    }
    my $metrics_list = $self->request_api(method => 'GET',service=>'ces', full_url =>$uri,hostname => '');
    return $metrics_list->{metrics};
}

sub internal_api_cloudeyes_get_metric {
     my ($self, %options) = @_;
    $self->{ces_endpoint} = 'https://ces.'.$self->{region}.".".$self->{endpoint_domain}.'/V1.0/'.$self->{project_id}.'/batch-query-metric-data';
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
    my $metrics_result = $self->request_api(method => 'POST',service=>'ces', query_form_post =>$encoded, full_url =>$self->{ces_endpoint},hostname => '');

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


sub api_list_obs_buckets {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://oss.'.$self->{endpoint_domain};
    my $list = $self->request_aws(method => 'GET', service=>'oss',full_url =>$self->{endpoint}.'',hostname => '');
    return $list;
}

sub api_obs_bucket_head {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://'.$options{bucket_name}.'.oss.'.$self->{endpoint_domain};
    (my $storage_class, my $storage_region) = $self->request_aws(method => 'HEAD', service=>'oss',full_url =>$self->{endpoint}.'',hostname => '');
    return ($storage_class, $storage_region);
}

sub api_get_obs_bucket_info {
    my ($self, %options) = @_;
    $self->{endpoint} = 'https://'.$options{bucket_name}.'.oss.'.$self->{endpoint_domain};
    my $list =  $self->request_aws(method => 'GET', service=>'oss',full_url =>defined($options{action})?$self->{endpoint}.'?'.$options{action}:$self->{endpoint},hostname => '');
    return $list;
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
    if ($options{service} eq 'dds'){
        $api_result = $self->api_list_dds_nodes(%options)
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

Flexible Engine API Access Key/Secret Key Mode
More Doc at 'https://docs.prod-cloud-ocb.orange-business.com/api/ecs/en-us_topic_0124306062.html'

=over 6

=item B<--domain-id>

Set Flexible Engine Domain ID.

=item B<--project-id>

Set Flexible Engine Project ID.

=item B<--access-key>

Set Flexible Engine Access Key.

=item B<--secret-key>

Set Flexible Engine Secret Key.

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
