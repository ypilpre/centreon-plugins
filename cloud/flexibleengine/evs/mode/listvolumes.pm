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

package cloud::flexibleengine::evs::mode::listvolumes;

use base qw(centreon::plugins::mode);


use strict;
use warnings;
 
sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
$options{options}->add_options(arguments => {
        "server-id:s" => { name => 'server_id' },
    });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);


    
}

sub manage_selection {
    my ($self, %options) = @_;
    $self->{volumes} = $options{custom}->api_list_evs();

}

sub run {
    my ($self, %options) = @_;
    $self->manage_selection(%options);
    foreach  (@{$self->{volumes}->{volumes}}) {
        my $attach_device;
     
         if (defined($self->{option_results}->{server_id}) && $self->{option_results}->{server_id} ne '' ){
         if  (defined($_->{attachments}[0]->{server_id})){
            next if ($_->{attachments}[0]->{server_id} ne $self->{option_results}->{server_id});
              
         }else{
             next;
         }
         };

        if  (defined($_->{attachments}[0]->{server_id})){
            if ($_->{attachments}[0]->{device} =~ /\/dev\/(.*)/) {
                $attach_device = $1;
            }
        };

        $self->{output}->output_add(
            long_msg => sprintf("[id = %s][name= %s][size= %s][server_id= %s][volumetype= %s][function= %s][device= %s][encrypted= %s][availabilityzone = %s][replication_status = %s][status = %s]",
         $_->{id},
         $_->{name},
         $_->{size},
         defined($_->{attachments}[0]->{server_id})?$_->{attachments}[0]->{server_id}:'',
         $_->{volume_type},
         ($_->{bootable} eq 'true')?'System':"Data",
        defined($attach_device)?$attach_device:'',
         $_->{encrypted},
         $_->{availability_zone},
        $_->{replication_status},
         $_->{status},));
    };
    $self->{output}->output_add(severity => 'OK',
                                short_msg => 'List volume:');
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['id', 'name', 'size','server_id','volumetype','function','device','encrypted','availabilityzone','replication_status','status']);
}

sub disco_show {
    my ($self, %options) = @_;
    
    $self->manage_selection(%options);
    foreach  (@{$self->{volumes}->{volumes}}) {
        my $attach_device;
         if (defined($self->{option_results}->{server_id}) && $self->{option_results}->{server_id} ne '' ){
         if  (defined($_->{attachments}[0]->{server_id})){
            next if ($_->{attachments}[0]->{server_id} ne $self->{option_results}->{server_id}) ;
         }else{
             next;
         }
         };

        if  (defined($_->{attachments}[0]->{server_id})){
            if ($_->{attachments}[0]->{device} =~ /\/dev\/(.*)/) {
                $attach_device = $1;
            }
        };


        $self->{output}->add_disco_entry(
        id => $_->{id},
        name => $_->{name},
        status => $_->{status},
        size => $_->{size},
        volume_type => $_->{volume_type},
        device =>  defined($attach_device)?$attach_device:'',
        function => ($_->{bootable} eq "true")?"System":"Data",
        encrypted => $_->{encrypted},
        server_id => defined($_->{attachments}[0]->{server_id})?$_->{attachments}[0]->{server_id}:'',
        availability_zone => $_->{availability_zone},
        replication_status => $_->{replication_status},
        );
    }
}

1;

__END__

=head1 MODE

List EVS volumes.

=over 8

=item B<--server-id

Filter Volumes by Server (First Attachment Only)

=back

=cut