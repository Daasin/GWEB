package WebGUI::AssetHelper::Lock;

use strict;
use WebGUI::International;
use base qw/WebGUI::AssetHelper/;

=head1 LEGAL

 -------------------------------------------------------------------
  WebGUI is Copyright 2001-2012 Plain Black Corporation.
 -------------------------------------------------------------------
  Please read the legal notices (docs/legal.txt) and the license
  (docs/license.txt) that came with this distribution before using
  this software.
 -------------------------------------------------------------------
  http://www.plainblack.com                     info@plainblack.com
 -------------------------------------------------------------------

=head1 NAME

Package WebGUI::AssetHelper::Lock

=head1 DESCRIPTION

Puts an edit lock on an Asset.

=head1 METHODS

These methods are available from this class:

=cut

#-------------------------------------------------------------------

=head2 process ()

Locks the asset with a version tag.  If the user cannot edit the asset, or the asset is
already locked, it returns an error message.

=cut

sub process {
    my ($self) = @_;
    my $asset = $self->asset;
    my $session = $self->session;

    my $i18n = WebGUI::International->new($session, 'Asset');
    if (! $asset->canEdit) {
        return { error => $i18n->get('38', 'WebGUI'), };
    }
    elsif ( $asset->isLocked ) {
        return { error => sprintf $i18n->get('already locked'), $asset->getTitle};
    }

    $asset->addRevision;
    return {
        message         => sprintf($i18n->get('locked asset'), $asset->getTitle),
        reload => 1,
    };
}

1;
