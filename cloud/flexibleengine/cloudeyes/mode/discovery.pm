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

package cloud::flexibleengine::cloudeyes::mode::discovery;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use JSON::XS;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "service:s@"    => { name => 'service' },
        "prettify"      => { name => 'prettify' },
    });

    $self->{services} = {
        VPC => $self->can('discover_vpc'),
        ECS => $self->can('discover_ecs'),
        RDS => $self->can('discover_rds'),
        ELB => $self->can('discover_elb'),
        CLB => $self->can('discover_clb'),
        NAT => $self->can('discover_nat'),
        DCS => $self->can('discover_dcs'),
        EIP => $self->can('discover_eip'),
        SFS => $self->can('discover_sfs'),
        EVS => $self->can('discover_evs'),
        CCE => $self->can('discover_cce'),
    };
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (!defined($self->{option_results}->{service}) || $self->{option_results}->{service} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --service option.");
        $self->{output}->option_exit();
    }
}

sub discover_vpc {
    my (%options) = @_;
    
    my @disco_data;

    my $vpcs = $options{custom}->discovery(region => $options{region},
        service => 'vpc');
    foreach my $vpc (@{$vpcs->{vpcs}}) {
        next if (!defined($vpc->{id}));
        my %vpc;
        $vpc{type} = "vpc";
        $vpc{id} = $vpc->{id};
        $vpc{status} = $vpc->{status};
        $vpc{cidr} = $vpc->{cidr};
        push @disco_data, \%vpc;
    }
    return @disco_data;
}

sub discover_ecs     {
    my (%options) = @_;

    my @disco_data;

    my $servers= $options{custom}->discovery(region => $options{region},
        service => 'ecs');
     foreach my $server (@{$servers}) {
            next if (!defined($server->{id}));            ;
            my %ecs;
            $ecs{type} = "ecs";
            $ecs{instance_id} = $server->{id};
            $ecs{name} = $server->{name};
            $ecs{status} = $server->{status};
            $ecs{state} = $server->{'OS-EXT-STS:vm_state'};
            $ecs{key_name} = $server->{key_name};
            $ecs{flavor} = $server->{flavor}->{id};
            $ecs{zone} = $server->{'OS-EXT-AZ:availability_zone'};
            $ecs{hypervisor} = $server->{'OS-EXT-SRV-ATTR:hypervisor_hostname'};
            push @disco_data, \%ecs;
    }
    return @disco_data;
}

sub discover_rds {
    my (%options) = @_;
    
    my @disco_data;

    my $db_instances = $options{custom}->discovery(region => $options{region},
        service => 'rds');
    foreach my $db_instance (@{$db_instances->{instances}}) {
        next if (!defined($db_instance->{id}));
        my %rds;
        $rds{type} = "rds";
        $rds{id} = $db_instance->{id};
        $rds{name} = $db_instance->{name};
        $rds{status} = $db_instance->{status};
        $rds{type} = $db_instance->{type};
        if ($db_instance->{type} eq 'Ha'){
        $rds{ha_type} = $db_instance->{ha}->{replication_mode};
        }
        $rds{flavor} = $db_instance->{flavor_ref};
        $rds{engine} = $db_instance->{datastore}->{type};
        $rds{engine_version} = $db_instance->{datastore}->{version};
        $rds{storage_type}= $db_instance->{volume}->{type};
        $rds{vpc_id} = $db_instance->{vpc_id};
        push @disco_data, \%rds;
    }
    return @disco_data;
}

sub discover_elb {
    my (%options) = @_;

    my @disco_data;

    my $load_balancers = $options{custom}->discovery(region => $options{region},
        service => 'elb', command => 'describe-load-balancers');
    foreach my $load_balancer (@{$load_balancers->{loadbalancers}}) {
        next if (!defined($load_balancer->{id}));
        my %elb;
        $elb{type} = "elb";
        $elb{id} = $load_balancer->{id};
        $elb{name} = $load_balancer->{name};
        $elb{operating_status} = $load_balancer->{operating_status};
        $elb{provisioning_status} = $load_balancer->{provisioning_status};
        $elb{vip_address} = $load_balancer->{vip_address};
        $elb{provider} = $load_balancer->{provider};
        push @disco_data, \%elb;
    }
    return @disco_data;
}

sub discover_clb {
    my (%options) = @_;

    my @disco_data;

    my $load_balancers = $options{custom}->discovery(region => $options{region},
        service => 'clb');
    foreach my $load_balancer (@{$load_balancers->{loadbalancers}}) {
        next if (!defined($load_balancer->{name}));
        my %clb;
        $clb{type} = "clb";
        $clb{name} = $load_balancer->{name};
        $clb{description} = $load_balancer->{description};
        $clb{id} = $load_balancer->{id};
        $clb{net_type} = $load_balancer->{type};
        $clb{vip_address} = $load_balancer->{vip_address};
        $clb{vpc_id} = $load_balancer->{vpc_id};
        push @disco_data, \%clb;
    }
    return @disco_data;
}

sub discover_eip {
    my (%options) = @_;

    my @disco_data;

    my $elastic_ips = $options{custom}->discovery(region => $options{region},
        service => 'eip');
    foreach my $elastic_ip (@{$elastic_ips->{publicips}}) {
        next if (!defined($elastic_ip->{id}));
        my %eip;
        $eip{type} = "eip";
        $eip{public_ip_address} = $elastic_ip->{public_ip_address};
        $eip{private_ip_address} = $elastic_ip->{private_ip_address};
        $eip{bandwidth_id} = $elastic_ip->{bandwidth_id};
        $eip{publicip_id} = $elastic_ip->{id};
        $eip{status} = $elastic_ip->{status};
        $eip{bandwidth_size} = $elastic_ip->{bandwidth_size};
        $eip{bandwidth_share_type} = $elastic_ip->{bandwidth_share_type};
        $eip{eip_type} = $elastic_ip->{type};
        push @disco_data, \%eip;
    }
    return @disco_data;
}

sub discover_dcs {
    my (%options) = @_;

    my @disco_data;

    my $distributed_caches = $options{custom}->discovery(region => $options{region},
        service => 'dcs');
    foreach my $distributed_cache (@{$distributed_caches->{instances}}) {
        next if (!defined($distributed_cache->{name}));
        my %dcs;
        $dcs{type} = "dcs";
        $dcs{name} = $distributed_cache->{name};
        $dcs{id} = $distributed_cache->{instance_id};
        $dcs{engine} = $distributed_cache->{engine};
        $dcs{engine_version} = $distributed_cache->{engine_version};
        $dcs{ip} = $distributed_cache->{ip};
        $dcs{spec_code} = $distributed_cache->{spec_code};
        $dcs{status} = $distributed_cache->{status};
        push @disco_data, \%dcs;
    }
    return @disco_data;
}

sub discover_sfs {
    my (%options) = @_;

    my @disco_data;

    my $scalable_file_systems = $options{custom}->discovery(region => $options{region},
        service => 'sfs');
    foreach my $scalable_file_system (@{$scalable_file_systems->{shares}}) {
        next if (!defined($scalable_file_system->{id}));
        my %sfs;
        $sfs{type} = "sfs";
        $sfs{name} = $scalable_file_system->{name};
        $sfs{share_id} = $scalable_file_system->{id};
        $sfs{status} = $scalable_file_system->{status};
        $sfs{size} = $scalable_file_system->{size};
        $sfs{share_proto} = $scalable_file_system->{share_proto};
        $sfs{availability_zone} = $scalable_file_system->{availability_zone};
        $sfs{status} = $scalable_file_system->{status};
        push @disco_data, \%sfs;
    }
    return @disco_data;
}

sub discover_nat {
    my (%options) = @_;
    my %spec = (
         1  => "small",
         2  => "medium",
         3  => "large",
         4 =>  "xlarge");
    my @disco_data;

    my $nat_gateways = $options{custom}->discovery(region => $options{region},
        service => 'nat');
    foreach my $nat_gateway (@{$nat_gateways->{nat_gateways}}) {
        next if (!defined($nat_gateway->{id}));
        my %nat;
        $nat{type} = "nat";
        $nat{name} = $nat_gateway->{name};
        $nat{id} = $nat_gateway->{id};
        $nat{description} = $nat_gateway->{description};
        $nat{status} = $nat_gateway->{status};
        $nat{id} = $nat_gateway->{id};
        $nat{spec} = $spec{lc($nat_gateway->{spec})};
        $nat{admin_state_up} = $nat_gateway->{admin_state_up};
        $nat{dnat_rules_limit} = $nat_gateway->{dnat_rules_limit};
        $nat{snat_rule_public_ip_limit} = $nat_gateway->{snat_rule_public_ip_limit};
        $nat{network_id}=$nat_gateway->{network_id};
        push @disco_data, \%nat;
    }
    return @disco_data;
}


sub discover_evs {
    my (%options) = @_;

    my @disco_data;

    my $volume_services = $options{custom}->discovery(region => $options{region},
        service => 'evs');
    
    foreach my $volume_service (@{$volume_services->{volumes}}) {
        next if (!defined($volume_service->{id}));
        my %evs;
        $evs{type} = "evs";
        $evs{disk_name} = $volume_service->{id};
        $evs{name} = $volume_service->{name};
        $evs{status} = $volume_service->{status};
        $evs{size} = $volume_service->{size};
        $evs{volume_type} = $volume_service->{volume_type};
        $evs{encrypted} = $volume_service->{encrypted};
        $evs{availability_zone} = $volume_service->{availability_zone};
        $evs{replication_status} = $volume_service->{replication_status};
        push @disco_data, \%evs;
    }

    return @disco_data;
}

sub discover_cce {
    my (%options) = @_;

    my @disco_data;

    my $cce_clusters = $options{custom}->discovery(region => $options{region},
        service => 'cce');

    foreach my $cce_cluster (@{$cce_clusters->{items}}) {
        next if (!defined($cce_cluster->{metadata}->{uid}));
        my %cce;
        $cce{type} = "cce";
        $cce{id} = $cce_cluster->{metadata}->{uid};
        $cce{name} = $cce_cluster->{metadata}->{name};
        $cce{status} = $cce_cluster->{status}->{phase};
        $cce{flavor} = $cce_cluster->{spec}->{flavor};
        $cce{type} = $cce_cluster->{spec}->{type};
        $cce{availability_zone} = $cce_cluster->{spec}->{az};
        $cce{version} = $cce_cluster->{spec}->{version};
        $cce{vpc_id} = $cce_cluster->{spec}->{hostNetwork}->{vpc};
        push @disco_data, \%cce;
    }

    return @disco_data;
}


sub run {
    my ($self, %options) = @_;

    my @disco_data;
    my $disco_stats;

    $disco_stats->{start_time} = time();

    foreach my $service (@{$self->{option_results}->{service}}) {
        push @disco_data, $self->{services}->{uc($service)}->(custom => $options{custom},
            region => $self->{option_results}->{region}) if (defined($self->{services}->{uc($service)}));
    }

    $disco_stats->{end_time} = time();
    $disco_stats->{duration} = $disco_stats->{end_time} - $disco_stats->{start_time};
    $disco_stats->{discovered_items} = @disco_data;
    $disco_stats->{results} = \@disco_data;

    my $encoded_data;
    eval {
        if (defined($self->{option_results}->{prettify})) {
            $encoded_data = JSON::XS->new->utf8->pretty->encode($disco_stats);
        } else {
            $encoded_data = JSON::XS->new->utf8->encode($disco_stats);
        }
    };
    if ($@) {
        $encoded_data = '{"code":"encode_error","message":"Cannot encode discovered data into JSON format"}';
    }
    
    $self->{output}->output_add(short_msg => $encoded_data);
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1);
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Resources discovery.

=over 8

=item B<--service>

Choose the service from which discover
resources (Can be: 'VPC','ECS','RDS',
'ELB','CLB,'NAT','VPN','RDS','CCE') (Mandatory).

=item B<--prettify>

Prettify JSON output.

=back

=cut
