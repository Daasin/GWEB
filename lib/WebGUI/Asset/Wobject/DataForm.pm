package WebGUI::Asset::Wobject::DataForm;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2004 Plain Black Corporation.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict qw(vars subs);
use Tie::CPHash;
use Tie::IxHash;
use WebGUI::DateTime;
use WebGUI::Form;
use WebGUI::FormProcessor;
use WebGUI::HTMLForm;
use WebGUI::HTTP;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Macro;
use WebGUI::MessageLog;
use WebGUI::Privilege;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::Style;
use WebGUI::TabForm;
use WebGUI::URL;
use WebGUI::Asset::Wobject;
use WebGUI::Utility;

our @ISA = qw(WebGUI::Asset::Wobject);

#-------------------------------------------------------------------
sub _createField {
	my $data = $_[0];
	my %param;
	$param{name} = $data->{name};
	$param{name} = "field_".$data->{sequenceNumber} if ($param{name} eq ""); # Empty fieldname not allowed
	$session{form}{$param{name}} =~ s/\^.*?\;//gs ; # remove macro's from user input
	$param{value} = $data->{value};
	$param{size} = $data->{width};
	$param{rows} = $data->{rows} || 5;
	$param{columns} = $data->{width};
	$param{vertical} = $data->{vertical};
	$param{extras} = $data->{extras};
		
	if ($data->{type} eq "checkbox") {
		$param{value} = ($data->{defaultValue} =~ /checked/i) ? 1 : "";
	}
	if (isIn($data->{type},qw(selectList checkList))) {
		my @defaultValues;
		if ($session{form}{$param{name}}) {
                	@defaultValues = $session{cgi}->param($param{name});
                } else {
                	foreach (split(/\n/, $data->{value})) {
                        	s/\s+$//; # remove trailing spaces
                                push(@defaultValues, $_);
                	}
                }
		$param{value} = \@defaultValues;
	}
	if (isIn($data->{type},qw(selectList checkList radioList))) {
		delete $param{size};
		my %options;
                tie %options, 'Tie::IxHash';
                foreach (split(/\n/, $data->{possibleValues})) {
                	s/\s+$//; # remove trailing spaces
                        $options{$_} = $_;
                }
		$param{options} = \%options;
	} 
	if ($data->{type} eq "yesNo") {
		if ($data->{defaultValue} =~ /yes/i) {
                	$param{value} = 1;
                } elsif ($data->{defaultValue} =~ /no/i) {
                	$param{value} = 0;
                }
	}
	my $cmd = "WebGUI::Form::".$data->{type};
	return &$cmd(\%param);
}

#-------------------------------------------------------------------
sub _fieldAdminIcons {
	my $fid = $_[1];
	my $tid = $_[2];
	my $output;
	$output = deleteIcon('func=deleteFieldConfirm&wid='.$_[0]->get("wobjectId").'&fid='.$fid.'&tid='.$tid,'',WebGUI::International::get(19,$_[0]->get("namespace"))) unless ($_[3]);
	$output .= editIcon('func=editField&wid='.$_[0]->get("wobjectId").'&fid='.$fid.'&tid='.$tid)
		.moveUpIcon('func=moveFieldUp&wid='.$_[0]->get("wobjectId").'&fid='.$fid.'&tid='.$tid)
		.moveDownIcon('func=moveFieldDown&wid='.$_[0]->get("wobjectId").'&fid='.$fid.'&tid='.$tid);
	return $output;
}
#-------------------------------------------------------------------
sub _tabAdminIcons {
	my $tid = $_[1];
	my $output;
	$output = deleteIcon('func=deleteTabConfirm&wid='.$_[0]->get("wobjectId").'&tid='.$tid,'',WebGUI::International::get(100,$_[0]->get("namespace"))) unless ($_[2]);
	$output .= editIcon('func=editTab&wid='.$_[0]->get("wobjectId").'&tid='.$tid)
		.moveLeftIcon('func=moveTabLeft&wid='.$_[0]->get("wobjectId").'&tid='.$tid)
		.moveRightIcon('func=moveTabRight&wid='.$_[0]->get("wobjectId").'&tid='.$tid);
	return $output;
}


#-------------------------------------------------------------------
sub _tonull { 
	return $_[1] eq "0" ? (undef, undef) : @_ ;
}


#-------------------------------------------------------------------
sub _createTabInit {
	my $wid = $_[0];
	my @tabCount = WebGUI::SQL->quickArray("select count(DataForm_tabId) from DataForm_tab where wobjectId=".quote($wid));
	my $output = '<script type="text/javascript"> var numberOfTabs = '.$tabCount[0].'; initTabs();</script>';
	return $output;
}

#-------------------------------------------------------------------
sub duplicate {
       my ($w, %dataField, %dataTab, $sthField, $sthTab, $newTabId);
       tie %dataTab, 'Tie::CPHash';
       tie %dataField, 'Tie::CPHash';
       $w = $_[0]->SUPER::duplicate($_[1]);
       $w = WebGUI::Wobject::DataForm->new({wobjectId=>$w,namespace=>$_[0]->get("namespace")});
       $sthTab = WebGUI::SQL->read("select * from DataForm_tab where wobjectId=".quote($_[0]->get("wobjectId")));
       while (%dataTab = $sthTab->hash) {
               $sthField = WebGUI::SQL->read("select * from DataForm_field where wobjectId=".quote($_[0]->get("wobjectId"))." AND DataForm_tabId=".quote($dataTab{DataForm_tabId}));
               $dataTab{DataForm_tabId} = "new";
               $newTabId = $w->setCollateral("DataForm_tab","DataForm_tabId",\%dataTab);
               while (%dataField = $sthField->hash) {
                       $dataField{DataForm_fieldId} = "new";
                       $dataField{DataForm_tabId} = $newTabId;
                       $w->setCollateral("DataForm_field","DataForm_fieldId",\%dataField);
               }
               $sthField->finish;
       }
       $sthField = WebGUI::SQL->read("select * from DataForm_field where wobjectId=".quote($_[0]->get("wobjectId"))." AND DataForm_tabId='0'");
       while (%dataField = $sthField->hash) {
               $dataField{DataForm_fieldId} = "new";
               $w->setCollateral("DataForm_field","DataForm_fieldId",\%dataField);
       }
       $sthField->finish;
       $sthTab->finish;
}

#-------------------------------------------------------------------
sub getIcon {
	my $self = shift;
	my $small = shift;
	return $session{config}{extrasURL}.'/assets/small/dataForm.gif' if ($small);
	return $session{config}{extrasURL}.'/assets/dataForm.gif';
}

#-------------------------------------------------------------------
sub getIndexerParams {
	my $self = shift;        
	my $now = shift;
	return {
		DataForm_field => {
                        sql => "select DataForm_field.label as label,
                                        DataForm_field.subtext as subtext,
                                        DataForm_field.possibleValues as possibleValues,
                                        DataForm_field.wobjectId as wid,
                                        DataForm_field.DataForm_fieldId as fid,
                                        wobject.namespace as namespace,
                                        wobject.addedBy as ownerId,
                                        page.urlizedTitle as urlizedTitle,
                                        page.languageId as languageId,
                                        page.pageId as pageId,
                                        page.groupIdView as page_groupIdView,
                                        wobject.groupIdView as wobject_groupIdView,
                                        7 as wobject_special_groupIdView
                                        from DataForm_field, wobject, page
                                        where DataForm_field.wobjectId = wobject.wobjectId
                                        and wobject.pageId = page.pageId
                                        and wobject.startDate < $now 
                                        and wobject.endDate > $now
                                        and page.startDate < $now
                                        and page.endDate > $now",
                        fieldsToIndex => ["label", "subtext", "possibleValues"],
                        contentType => 'wobjectDetail',
                        url => '$data{urlizedTitle}."#".$data{wid}',
                        headerShortcut => 'select label from DataForm_field where DataForm_fieldId = \'$data{fid}\'',
                        bodyShortcut => 'select subtext from DataForm_field where DataForm_fieldId = \'$data{fid}\'',
                },
        DataForm_entryData => {
                        sql => "select distinct(DataForm_entryData.wobjectId) as wid,
                                        wobject.namespace as namespace,
                                        wobject.addedBy as ownerId,
                                        page.urlizedTitle as urlizedTitle,
                                        page.languageId as languageId,
                                        page.pageId as pageId,
                                        page.groupIdView as page_groupIdView,
                                        wobject.groupIdView as wobject_groupIdView,
                                        wobject.groupIdEdit as wobject_special_groupIdView
                                        from DataForm_entryData, wobject, page
                                        where DataForm_entryData.wobjectId = wobject.wobjectId
                                        and wobject.pageId = page.pageId
                                        and wobject.startDate < $now 
                                        and wobject.endDate > $now
                                        and page.startDate < $now
                                        and page.endDate > $now",
                        fieldsToIndex => ['select distinct(value) from DataForm_entryData where wobjectId = \'$data{wid}\''],
                        contentType => 'wobjectDetail',
                        url => 'WebGUI::URL::append($data{urlizedTitle}, "func=view&entryId=list&wid=$data{wid}")',
                        headerShortcut => 'select title from wobject where wobjectId = \'$data{wid}\'',
                }
	};
}


#-------------------------------------------------------------------
sub getListTemplateVars {
	my $self = shift;
	my $var = shift;
	my @fieldLoop;
	$var->{"back.url"} = WebGUI::URL::page();
	$var->{"back.label"} = WebGUI::International::get(18,$self->get("namespace"));
	my $a = WebGUI::SQL->read("select DataForm_fieldId,name,label,isMailField,type from DataForm_field
		where wobjectId=".quote($self->get("wobjectId"))." order by sequenceNumber");
	while (my $field = $a->hashRef) {
		push(@fieldLoop,{
			"field.name"=>$field->{name},
			"field.id"=>$field->{DataForm_fieldId},
			"field.label"=>$field->{label},
			"field.isMailField"=>$field->{isMailField},
			"field.type"=>$field->{type},
			});
	}
	$a->finish;
	$var->{field_loop} = \@fieldLoop;
	my @recordLoop;
	my $a = WebGUI::SQL->read("select ipAddress,username,userid,submissionDate,DataForm_entryId from DataForm_entry 
		where wobjectId=".quote($self->get("wobjectId"))." order by submissionDate desc");
	while (my $record = $a->hashRef) {
		my @dataLoop;
		my $b = WebGUI::SQL->read("select b.name, b.label, b.isMailField, a.value from DataForm_entryData a left join DataForm_field b
			on a.DataForm_fieldId=b.DataForm_fieldId where a.DataForm_entryId=".quote($record->{DataForm_entryId})."
			order by b.sequenceNumber");
		while (my $data = $b->hashRef) {
			push(@dataLoop,{
				"record.data.name"=>$data->{name},
				"record.data.label"=>$data->{label},
				"record.data.value"=>$data->{value},
				"record.data.isMailField"=>$data->{isMailField}
				});
		}
		$b->finish;
		push(@recordLoop,{
			"record.ipAddress"=>$record->{ipAddress},
			"record.edit.url"=>WebGUI::URL::page("func=view&entryId=".$record->{DataForm_entryId}."&wid=".$self->get("wobjectId")),
			"record.edit.icon"=>editIcon("func=view&entryId=".$record->{DataForm_entryId}."&wid=".$self->get("wobjectId")),
			"record.delete.url"=>WebGUI::URL::page("func=deleteEntry&entryId=".$record->{DataForm_entryId}."&wid=".$self->get("wobjectId")),
			"record.delete.icon"=>deleteIcon("func=deleteEntry&entryId=".$record->{DataForm_entryId}."&wid=".$self->get("wobjectId"),'',WebGUI::International::get('Delete entry confirmation',$self->get('namespace'))),
			"record.username"=>$record->{username},
			"record.userId"=>$record->{userId},
			"record.submissionDate.epoch"=>$record->{submissionDate},
			"record.submissionDate.human"=>WebGUI::DateTime::epochToHuman($record->{submissionDate}),
			"record.entryId"=>$record->{DataForm_entryId},
			"record.data_loop"=>\@dataLoop
			});
	}
	$a->finish;
	$var->{record_loop} = \@recordLoop;
	return $var;
}

#-------------------------------------------------------------------
sub getRecordTemplateVars {
	my $self = shift;
	my $var = shift;
	$var->{error_loop} = [] unless (exists $var->{error_loop});
	$var->{canEdit} = ($self->canEdit);
	$var->{"entryList.url"} = WebGUI::URL::page('func=view&entryId=list&wid='.$self->get("wobjectId"));
	$var->{"entryList.label"} = WebGUI::International::get(86,$self->get("namespace"));
	$var->{"export.tab.url"} = WebGUI::URL::page('func=exportTab&wid='.$self->get("wobjectId"));
	$var->{"export.tab.label"} = WebGUI::International::get(84,$self->get("namespace"));
	$var->{"delete.url"} = WebGUI::URL::page('func=deleteEntry&wid='.$self->get("wobjectId").'&entryId='.$var->{entryId});
	$var->{"delete.label"} = WebGUI::International::get(90,$self->get("namespace"));
	$var->{"back.url"} = WebGUI::URL::page();
	$var->{"back.label"} = WebGUI::International::get(18,$self->get("namespace"));
	$var->{"addField.url"} = WebGUI::URL::page('func=editField&wid='.$self->get("wobjectId"));
	$var->{"addField.label"} = WebGUI::International::get(76,$self->get("namespace"));
	# add Tab label, url, header and init
	$var->{"addTab.label"}=  WebGUI::International::get(105,$self->get("namespace"));;
	$var->{"addTab.url"}= WebGUI::URL::page('func=editTab&wid='.$self->get("wobjectId"));
	$var->{"tab.init"}= _createTabInit($self->get("wobjectId"));
	$var->{"form.start"} = WebGUI::Form::formHeader()
		.WebGUI::Form::hidden({name=>"wid",value=>$self->get("wobjectId")})
		.WebGUI::Form::hidden({name=>"func",value=>"process"});
	my @tabs;
	my $select = "select a.name, a.DataForm_fieldId, a.DataForm_tabId,a.label, a.status, a.isMailField, a.subtext, a.type, a.defaultValue, a.possibleValues, a.width, a.rows, a.extras, a.vertical";
	my $join;
	my $where = "where a.wobjectId=".quote($self->get("wobjectId"));
	if ($var->{entryId}) {
		$var->{"form.start"} .= WebGUI::Form::hidden({name=>"entryId",value=>$var->{entryId}});
		my $entry = $self->getCollateral("DataForm_entry","DataForm_entryId",$var->{entryId});
		$var->{ipAddress} = $entry->{ipAddress};
		$var->{username} = $entry->{username};
		$var->{userId} = $entry->{userId};
		$var->{date} = WebGUI::DateTime::epochToHuman($entry->{submissionDate});
		$var->{epoch} = $entry->{submissionDate};
		$var->{"edit.URL"} = WebGUI::URL::page('func=view&wid='.$self->get("wobjectId").'&entryId='.$var->{entryId});
		$where .= " and b.DataForm_entryId=".quote($var->{entryId});
		$join = "left join DataForm_entryData as b on a.DataForm_fieldId=b.DataForm_fieldId";
		$select .= ", b.value";
	}
	my %data;
	tie %data, 'Tie::CPHash';
	my %tab;
	tie %tab, 'Tie::CPHash';
	my $tabsth = WebGUI::SQL->read("select * from DataForm_tab where wobjectId=".quote($self->get("wobjectId"))." order by sequenceNumber");
	while (%tab = $tabsth->hash) {
		my @fields;
		my $sth = WebGUI::SQL->read("$select from DataForm_field as a $join $where and a.DataForm_tabId=".quote($tab{DataForm_tabId})." order by a.sequenceNumber");
		while (%data = $sth->hash) {
			my $formValue = $session{form}{$data{name}};
			if ((not exists $data{value}) && $session{form}{func} ne "editSave" && $session{form}{func} ne "editFieldSave" && defined $formValue) {
				$data{value} = $formValue;
				$data{value} = WebGUI::DateTime::setToEpoch($data{value}) if ($data{type} eq "date");
			}
			if (not exists $data{value}) {
				$data{value} = WebGUI::Macro::process($data{defaultValue});
			}
			my $hidden = (($data{status} eq "hidden" && !$session{var}{adminOn}) || ($data{isMailField} && !$self->get("mailData")));
			my $value = $data{value};
			$value = WebGUI::DateTime::epochToHuman($value,"%z") if ($data{type} eq "date");
			$value = WebGUI::DateTime::epochToHuman($value,"%z %Z") if ($data{type} eq "dateTime");
			push(@fields, {
				"tab.field.form" => _createField(\%data),
				"tab.field.name" => $data{name},
				"tab.field.tid" => $data{DataForm_tabId},
				"tab.field.value" => $value,
				"tab.field.label" => $data{label},
				"tab.field.isMailField" => $data{isMailField},
				"tab.field.isHidden" => $hidden,
				"tab.field.isDisplayed" => ($data{status} eq "visible" && !$hidden),
				"tab.field.isRequired" => ($data{status} eq "required" && !$hidden),
				"tab.field.subtext" => $data{subtext},
				"tab.field.controls" => $self->_fieldAdminIcons($data{DataForm_fieldId},$data{DataForm_tabId},$data{isMailField})
			});
		}
		$sth->finish;
		push(@tabs, {
			"tab.start" => '<div id="tabcontent'.$tab{sequenceNumber}.'" class="tabBody">',
			"tab.end" =>'</div>',
			"tab.sequence" => $tab{sequenceNumber},
			"tab.label" => $tab{label},
			"tab.tid" => $tab{DataForm_tabId},
			"tab.subtext" => $tab{subtext},
			"tab.controls" => $self->_tabAdminIcons($tab{DataForm_tabId}),
			"tab.field_loop" => \@fields,
		});
	}
	
	my @fields;
	my $sth = WebGUI::SQL->read("$select from DataForm_field as a $join $where and a.DataForm_tabId = 0 order by a.sequenceNumber");
	while (%data = $sth->hash) {
		my $formValue = $session{form}{$data{name}};
		if ((not exists $data{value}) && $session{form}{func} ne "editSave" && $session{form}{func} ne "editFieldSave" && defined $formValue) {
			$data{value} = $formValue;
			$data{value} = WebGUI::DateTime::setToEpoch($data{value}) if ($data{type} eq "date");
		}
		if (not exists $data{value}) {
			$data{value} = WebGUI::Macro::process($data{defaultValue});
		}
		my $hidden = (($data{status} eq "hidden" && !$session{var}{adminOn}) || ($data{isMailField} && !$self->get("mailData")));
		my $value = $data{value};
		$value = WebGUI::DateTime::epochToHuman($value,"%z") if ($data{type} eq "date");
		$value = WebGUI::DateTime::epochToHuman($value) if ($data{type} eq "dateTime");
		my %fieldProperties = (
			"form" => _createField(\%data),
			"name" => $data{name},
			"tid" => $data{DataForm_tabId},
			"inTab".$data{DataForm_tabId} => 1,
			"value" => $value,
			"label" => $data{label},
			"isMailField" => $data{isMailField},
			"isHidden" => $hidden,
			"isDisplayed" => ($data{status} eq "visible" && !$hidden),
			"isRequired" => ($data{status} eq "required" && !$hidden),
			"subtext" => $data{subtext},
			"controls" => $self->_fieldAdminIcons($data{DataForm_fieldId},$data{DataForm_tabId},$data{isMailField})
		);
		push(@fields, { map {("field.".$_ => $fieldProperties{$_})} keys(%fieldProperties) });
		foreach (keys(%fieldProperties)) {
			$var->{"field.noloop.".$data{name}.".$_"} = $fieldProperties{$_};
		}
	}
	$sth->finish;
	$var->{field_loop} = \@fields;
	$tabsth->finish;
	$var->{tab_loop} = \@tabs;
	$var->{"form.send"} = WebGUI::Form::submit({value=>WebGUI::International::get(73, $self->get("namespace"))});
	$var->{"form.save"} = WebGUI::Form::submit();
	$var->{"form.end"} = WebGUI::Form::formFooter();
	return $var;
}

#-------------------------------------------------------------------
sub name {
        return WebGUI::International::get(1,$_[0]->get("namespace"));
}

#-------------------------------------------------------------------
sub definition {
	my $class = shift;
        my $definition = shift;
        push(@{$definition}, {
                tableName=>'DataForm',
                className=>'WebGUI::Asset::Wobject::DataForm',
                properties=>{
			acknowledgement=>{
				fieldType=>"textarea",
				defaultValue=>undef
				},
			emailTemplateId=>{
				fieldType=>"template",
				defaultValue=>undef
				},
			acknowlegementTemplateId=>{
				defaultValue=>undef,
				fieldType=>"template"
				},
			listTemplateId=>{
				defaultValue=>undef,
				fieldType=>"template"
				},
			mailData=>{
				defaultValue=>0,
				fieldType=>"yesNo"
				}
			}
		});
        return $class->SUPER::definition($definition);
}

#-------------------------------------------------------------------
sub purge {
    	WebGUI::SQL->write("delete from DataForm_field where wobjectId=".quote($_[0]->get("wobjectId")));
    	WebGUI::SQL->write("delete from DataForm_entry where wobjectId=".quote($_[0]->get("wobjectId")));
    	WebGUI::SQL->write("delete from DataForm_entryData where wobjectId=".quote($_[0]->get("wobjectId")));
	WebGUI::SQL->write("delete from DataForm_tab where wobjectId=".quote($_[0]->get("wobjectId")));
    	$_[0]->SUPER::purge();
}

#-------------------------------------------------------------------
sub sendEmail {
	my $var = $_[1];
	my $message = WebGUI::Macro::process($_[0]->processTemplate($_[0]->get("emailTemplateId"),$var));
	my ($to, $subject, $from, $bcc, $cc);
	foreach my $row (@{$var->{field_loop}}) {
		if ($row->{"field.name"} eq "to") {
			$to = $row->{"field.value"};
		} elsif ($row->{"field.name"} eq "from") {
			$from = $row->{"field.value"};
		} elsif ($row->{"field.name"} eq "cc") {
			$cc = $row->{"field.value"};
		} elsif ($row->{"field.name"} eq "bcc") {
			$bcc = $row->{"field.value"};
		} elsif ($row->{"field.name"} eq "subject") {
			$subject = $row->{"field.value"};
		}
	}
	if ($to =~ /\@/) {
		WebGUI::Mail::send($to, $subject, $message, $cc, $from, $bcc);
	} else {
                my ($userId) = WebGUI::SQL->quickArray("select userId from users where username=".quote($to));
                my $groupId;
                # if no user is found, try finding a matching group
                unless ($userId) {
                        ($groupId) = WebGUI::SQL->quickArray("select groupId from groups where groupName=".quote($to));
                }
                unless ($userId || $groupId) {
                        WebGUI::ErrorHandler::warn($_[0]->get("wobjectId").": Unable to send message, no user or group found.");
                } else {
                        WebGUI::MessageLog::addEntry($userId, $groupId, $subject, $message, "", "", $from);
			if ($cc) {
                                WebGUI::Mail::send($cc, $subject, $message, "", $from);
                        }
                        if ($bcc) {
                                WebGUI::Mail::send($bcc, $subject, $message, "", $from);
                        }
                }
        }
}

#-------------------------------------------------------------------
sub uiLevel {
        return 5;
}

sub view {
	return "DataForm";
}

#-------------------------------------------------------------------
sub www_deleteEntry {
        return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
        my $entryId = $session{form}{entryId};
    	WebGUI::SQL->write("delete from DataForm_entry where DataForm_entryId=".quote($entryId));
        $session{form}{entryId} = 'list';
        return $_[0]->www_view();
}

#-------------------------------------------------------------------
sub www_deleteFieldConfirm {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->deleteCollateral("DataForm_field","DataForm_fieldId",$session{form}{fid});
	$_[0]->reorderCollateral("DataForm_field","DataForm_fieldId");
       	return "";
}

#-------------------------------------------------------------------
sub www_deleteTabConfirm {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->deleteCollateral("DataForm_tab","DataForm_tabId",$session{form}{tid});
	$_[0]->deleteCollateral("DataForm_field","DataForm_tabId",$session{form}{tid});
	$_[0]->reorderCollateral("DataForm_tab","DataForm_tabId");
       	return "";
}

#-------------------------------------------------------------------
sub www_edit {
	my $layout = WebGUI::HTMLForm->new;
        $layout->template(
                -name=>"emailTemplateId",
                -value=>$_[0]->getValue("emailTemplateId"),
                -namespace=>$_[0]->get("namespace"),
                -label=>WebGUI::International::get(80,$_[0]->get("namespace")),
                -afterEdit=>'func=edit&wid='.$_[0]->get("wobjectId")
                );
        $layout->template(
                -name=>"acknowlegementTemplateId",
                -value=>$_[0]->getValue("acknowlegementTemplateId"),
                -namespace=>$_[0]->get("namespace"),
                -label=>WebGUI::International::get(81,$_[0]->get("namespace")),
                -afterEdit=>'func=edit&wid='.$_[0]->get("wobjectId")
                );
        $layout->template(
                -name=>"listTemplateId",
                -value=>$_[0]->getValue("listTemplateId"),
                -namespace=>$_[0]->get("namespace")."/List",
                -label=>WebGUI::International::get(87,$_[0]->get("namespace")),
                -afterEdit=>'func=edit&wid='.$_[0]->get("wobjectId")
                );
	my $properties = WebGUI::HTMLForm->new;
	$properties->HTMLArea(
		-name=>"acknowledgement",
		-label=>WebGUI::International::get(16, $_[0]->get("namespace")),
		-value=>($_[0]->get("acknowledgement") || WebGUI::International::get(3, $_[0]->get("namespace")))
		);
	$properties->yesNo(
		-name=>"mailData",
		-label=>WebGUI::International::get(74,$_[0]->get("namespace")),
		-value=>$_[0]->getValue("mailData")
		);
	if ($_[0]->get("wobjectId") eq "new") {
        	$properties->whatNext(
			-options=>{
				addField=>WebGUI::International::get(76,$_[0]->get("namespace")),
				backToPage=>WebGUI::International::get(745)
				},
			-value=>"addField"
			);
	}
	return $_[0]->SUPER::www_edit(
		-properties=>$properties->printRowsOnly,
		-layout=>$layout->printRowsOnly,
		-helpId=>"data form add/edit",
		-headingId=>7
		);
}

#-------------------------------------------------------------------
sub www_editSave {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->SUPER::www_editSave();
	if ($session{form}{wid} eq "new") {
		$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
			DataForm_fieldId=>"new",
			name=>"from",
			label=>WebGUI::International::get(10,$_[0]->get("namespace")),
			status=>"editable",
			isMailField=>1,
			width=>0,
			type=>"email"
			});
		$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
			DataForm_fieldId=>"new",
			name=>"to",
			label=>WebGUI::International::get(11,$_[0]->get("namespace")),
			status=>"hidden",
			isMailField=>1,
			width=>0,
			type=>"email",
			defaultValue=>$session{setting}{companyEmail}
			});
		$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
			DataForm_fieldId=>"new",
			name=>"cc",
			label=>WebGUI::International::get(12,$_[0]->get("namespace")),
			status=>"hidden",
			isMailField=>1,
			width=>0,
			type=>"email"
			});
		$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
			DataForm_fieldId=>"new",
			name=>"bcc",
			label=>WebGUI::International::get(13,$_[0]->get("namespace")),
			status=>"hidden",
			isMailField=>1,
			width=>0,
			type=>"email"
			});
		$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
			DataForm_fieldId=>"new",
			name=>"subject",
			label=>WebGUI::International::get(14,$_[0]->get("namespace")),
			status=>"editable",
			isMailField=>1,
			width=>0,
			type=>"text",
			defaultValue=>WebGUI::International::get(2,$_[0]->get("namespace"))
			});
	}
        if ($session{form}{proceed} eq "addField") {
            	return $_[0]->www_editField();
        }
       	return "";
}

#-------------------------------------------------------------------
sub www_editField {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
    	my (%field, $f, %fieldStatus,$tab);
    	tie %field, 'Tie::CPHash';
    	tie %fieldStatus, 'Tie::IxHash';

	%fieldStatus = ( 
		"hidden" => WebGUI::International::get(4, $_[0]->get("namespace")),
		"visible" => WebGUI::International::get(5, $_[0]->get("namespace")),
		"editable" => WebGUI::International::get(6, $_[0]->get("namespace")),
		"required" => WebGUI::International::get(75, $_[0]->get("namespace")) 
		);
        $session{form}{fid} = "new" if ($session{form}{fid} eq "");
	unless ($session{form}{fid} eq "new") {	
        	%field = WebGUI::SQL->quickHash("select * from DataForm_field where DataForm_fieldId=".quote($session{form}{fid}));
	}
	$tab = WebGUI::SQL->buildHashRef("select DataForm_tabId,label from DataForm_tab where wobjectId=".quote($_[0]->get("wobjectId")));
	$tab->{0} = $_[0]->i18n("no tab");
        $f = WebGUI::HTMLForm->new;
        $f->hidden("wid",$_[0]->get("wobjectId"));
        $f->hidden("fid",$session{form}{fid});
        $f->hidden("func","editFieldSave");
	$f->text(
                -name=>"label",
                -label=>WebGUI::International::get(77,$_[0]->get("namespace")),
                -value=>$field{label}
                );
        $f->text(
		-name=>"name",
		-label=>WebGUI::International::get(21,$_[0]->get("namespace")),
		-value=>$field{name}
		);
	if($field{sequenceNumber} && ! $field{isMailField}) {
		$f->integer(
			-name=>"position",
			-label=>WebGUI::International::get('Field Position',$_[0]->get("namespace")),
			-value=>$field{sequenceNumber}
		);	
	}
	$f->select(
		-name=>"tid",
		-options=>$tab,
		-label=>WebGUI::International::get(104,$_[0]->get("namespace")),
		-value=>[ $field{DataForm_tabId}] || [0]
		); 
        $f->text(
                -name=>"subtext",
                -value=>$field{subtext},
                -label=>WebGUI::International::get(79,$_[0]->get("namespace")),
                );
        $f->select(
		-name=>"status",
		-options=>\%fieldStatus,
		-label=>WebGUI::International::get(22,$_[0]->get("namespace")),
		-value=>[ $field{status} ||= "editable" ]
		); 
	$f->fieldType(
		-name=>"type",
		-label=>WebGUI::International::get(23,$_[0]->get("namespace")),
		-value=>[$field{type} ||= "text"]
		);
	$f->integer(
		-name=>"width",
		-label=>WebGUI::International::get(8, $_[0]->get("namespace")),
		-value=>($field{width} || 0)
		);
	$f->integer(
                -name=>"rows",
		-value=>$field{rows} || 0,
		-label=>WebGUI::International::get(27, $_[0]->get("namespace")),
		-subtext=>WebGUI::International::get(28, $_[0]->get("namespace")),
		);
	$f->yesNo(
		-name=>"vertical",
		-value=>$field{vertical},
		-label=>WebGUI::International::get('editField-vertical-label', $_[0]->get("namespace")),
		-subtext=>WebGUI::International::get('editField-vertical-subtext', $_[0]->get("namespace"))
		);
	$f->text(
		-name=>"extras",
		-value=>$field{extras},
		-label=>WebGUI::International::get('editField-extras-label', $_[0]->get("namespace"))
		);
        $f->textarea(
		-name=>"possibleValues",
		-label=>WebGUI::International::get(24,$_[0]->get("namespace")),
		-value=>$field{possibleValues},
		-subtext=>'<br>'.WebGUI::International::get(85,$_[0]->get("namespace"))
		);
        $f->textarea(
		-name=>"defaultValue",
		-label=>WebGUI::International::get(25,$_[0]->get("namespace")),
		-value=>$field{defaultValue},
		-subtext=>'<br>'.WebGUI::International::get(85,$_[0]->get("namespace"))
		);
	if ($session{form}{fid} eq "new") {
        	$f->whatNext(
			-options=>{
				addField=>WebGUI::International::get(76,$_[0]->get("namespace")),
				backToPage=>WebGUI::International::get(745)
				},
			-value=>"addField"
			);
	}
        $f->submit;
        return $_[0]->adminConsole($f->print,'20',"data form fields add/edit");
}

#-------------------------------------------------------------------
sub www_editFieldSave {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$session{form}{name} = $session{form}{label} if ($session{form}{name} eq "");
	$session{form}{tid} = "0" if ($session{form}{tid} eq "");
	$session{form}{name} = WebGUI::URL::urlize($session{form}{name});
        $session{form}{name} =~ s/\-//g;
        $session{form}{name} =~ s/\///g;
	$_[0]->setCollateral("DataForm_field","DataForm_fieldId",{
		DataForm_fieldId=>$session{form}{fid},
		width=>$session{form}{width},
		name=>$session{form}{name},
		label=>$session{form}{label},
		DataForm_tabId=>$session{form}{tid},
		status=>$session{form}{status},
		type=>$session{form}{type},
		possibleValues=>$session{form}{possibleValues},
		defaultValue=>$session{form}{defaultValue},
		subtext=>$session{form}{subtext},
		rows=>$session{form}{rows},
		vertical=>$session{form}{vertical},
		extras=>$session{form}{extras},
		}, "1","1", _tonull("DataForm_tabId",$session{form}{tid}));
	if($session{form}{position}) {
		WebGUI::SQL->write("update DataForm_field set sequenceNumber=".quote($session{form}{position}).
					" where DataForm_fieldId=".quote($session{form}{fid}));
	}
	$_[0]->reorderCollateral("DataForm_field","DataForm_fieldId", _tonull("DataForm_tabId",$session{form}{tid})) if ($session{form}{fid} ne "new");
        if ($session{form}{proceed} eq "addField") {
            	$session{form}{fid} = "new";
            	return $_[0]->www_editField();
        }
        return "";
}

#-------------------------------------------------------------------
sub www_editTab {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
    	my (%tab, $f);
    	tie %tab, 'Tie::CPHash';

        $session{form}{tid} = "new" if ($session{form}{tid} eq "");
	unless ($session{form}{tid} eq "new") {	
        	%tab = WebGUI::SQL->quickHash("select * from DataForm_tab where DataForm_tabId=".quote($session{form}{tid}));
	}
        $f = WebGUI::HTMLForm->new;
        $f->hidden("wid",$_[0]->get("wobjectId"));
        $f->hidden("tid",$session{form}{tid});
        $f->hidden("func","editTabSave");
	$f->text(
                -name=>"label",
		-label=>WebGUI::International::get(101,$_[0]->get("namespace")),
                -value=>$tab{label}
                );
        $f->textarea(
		-name=>"subtext",
		-label=>WebGUI::International::get(102,$_[0]->get("namespace")),
		-value=>$tab{subtext},
		-subtext=>""
		);
	if ($session{form}{tid} eq "new") {
        	$f->whatNext(
			-options=>{
				addTab=>WebGUI::International::get(103,$_[0]->get("namespace")),

				backToPage=>WebGUI::International::get(745)
				},
			-value=>"addTab"
			);
	}
        $f->submit;
        return $_[0]->adminConsole($f->print,'20',"data form fields add/edit");
}

#-------------------------------------------------------------------
sub www_editTabSave {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$session{form}{name} = $session{form}{label} if ($session{form}{name} eq "");
	$session{form}{name} = WebGUI::URL::urlize($session{form}{name});
        $session{form}{name} =~ s/\-//g;
        $session{form}{name} =~ s/\///g;
	$_[0]->setCollateral("DataForm_tab","DataForm_tabId",{
		DataForm_tabId=>$session{form}{tid},
		label=>$session{form}{label},
		subtext=>$session{form}{subtext}
		});
        if ($session{form}{proceed} eq "addTab") {
            	$session{form}{tid} = "new";
            	return $_[0]->www_editTab();
        }
        return "";
}

#-------------------------------------------------------------------
sub www_exportTab {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	WebGUI::HTTP::setFilename(WebGUI::URL::urlize($_[0]->get("title")).".tab","text/plain");
	my %fields = WebGUI::SQL->buildHash("select DataForm_fieldId,name from DataForm_field where wobjectId=".quote($_[0]->get("wobjectId"))." order by sequenceNumber");
	my $select = "select a.DataForm_entryId as entryId, a.ipAddress, a.username, a.userId, a.submissionDate";
	my $from = " from DataForm_entry a";
	my $join;
	my $where = " where a.wobjectId=".quote($_[0]->get("wobjectId"));
	my $orderBy = " order by a.DataForm_entryId";
	my $columnCounter = "b";
	foreach my $fieldId (keys %fields) {
		my $extension = "";
		$extension = "mail_" if (isIn($fields{$fieldId}, qw(to from cc bcc subject)));
		$select .= ", ".$columnCounter.".value as ".$extension.$fields{$fieldId};
		$join .= " left join DataForm_entryData ".$columnCounter." on a.DataForm_entryId=".$columnCounter.".DataForm_entryId and "
			.$columnCounter.".DataForm_fieldId=".quote($fieldId);
		$columnCounter++;
	}
	return WebGUI::SQL->quickTab($select.$from.$join.$where.$orderBy);
}

#-------------------------------------------------------------------
sub www_moveFieldDown {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->moveCollateralDown("DataForm_field","DataForm_fieldId",$session{form}{fid},_tonull("DataForm_tabId",$session{form}{tid}));
	return "";
}

#-------------------------------------------------------------------
sub www_moveFieldUp {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->moveCollateralUp("DataForm_field","DataForm_fieldId",$session{form}{fid},_tonull("DataForm_tabId",$session{form}{tid}));
	return "";
}

#-------------------------------------------------------------------
sub www_moveTabRight {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->moveCollateralDown("DataForm_tab","DataForm_tabId",$session{form}{tid});
	return "";
}

#-------------------------------------------------------------------
sub www_moveTabLeft {
	return WebGUI::Privilege::insufficient() unless ($_[0]->canEdit);
	$_[0]->moveCollateralUp("DataForm_tab","DataForm_tabId",$session{form}{tid});
	return "";
}

#-------------------------------------------------------------------
sub www_process {
	my $entryId = $_[0]->setCollateral("DataForm_entry","DataForm_entryId",{
		DataForm_entryId=>$session{form}{entryId},
                wobjectId=>$_[0]->get("wobjectId"),
                userId=>$session{user}{userId},
                username=>$session{user}{username},
                ipAddress=>$session{env}{REMOTE_ADDR},
                submissionDate=>time()
		},0);
	my ($var, %row, @errors, $updating, $hadErrors);
	$var->{entryId} = $entryId;
	tie %row, "Tie::CPHash";
	my $sth = WebGUI::SQL->read("select DataForm_fieldId,label,name,status,type,defaultValue,isMailField from DataForm_field 
		where wobjectId=".quote($_[0]->get("wobjectId"))." order by sequenceNumber");
	while (%row = $sth->hash) {
		my $value = $row{defaultValue};
		if ($row{status} eq "required" || $row{status} eq "editable") {
			$value = WebGUI::FormProcessor::process($row{name},$row{type},$row{defaultValue});
			$value = WebGUI::Macro::filter($value);
		}
		if ($row{status} eq "required" && ($value =~ /^\s$/ || $value eq "" || not defined $value)) {
			push (@errors,{
				"error.message"=>$row{label}." ".WebGUI::International::get(29,$_[0]->get("namespace")).".",
				});
			$hadErrors = 1;
			delete $var->{entryId};
		}
		if ($row{status} eq "hidden") {
                        $value = WebGUI::Macro::process($row{defaultValue});
                }
		unless ($hadErrors) {
			my ($exists) = WebGUI::SQL->quickArray("select count(*) from DataForm_entryData where DataForm_entryId=".quote($entryId)."
				and DataForm_fieldId=".quote($row{DataForm_fieldId}));
			if ($exists) {
				WebGUI::SQL->write("update DataForm_entryData set value=".quote($value)."
					where DataForm_entryId=".quote($entryId)." and DataForm_fieldId=".quote($row{DataForm_fieldId}));
				$updating = 1;
			} else {
				WebGUI::SQL->write("insert into DataForm_entryData (DataForm_entryId,DataForm_fieldId,wobjectId,value) values
					(".quote($entryId).", ".quote($row{DataForm_fieldId}).", ".quote($_[0]->get("wobjectId")).", ".quote($value).")");
			}
		}
	}
	$sth->finish;
	$var->{error_loop} = \@errors;
	$var = $_[0]->getRecordTemplateVars($var);
	if ($hadErrors && !$updating) {
		WebGUI::SQL->write("delete from DataForm_entryData where DataForm_entryId=".quote($entryId));
		$_[0]->deleteCollateral("DataForm_entry","DataForm_entryId",$entryId);
		$_[0]->www_view($var);
	} else {
		$_[0]->sendEmail($var) if ($_[0]->get("mailData") && !$updating);
		return $_[0]->processTemplate($_[0]->get("acknowlegementTemplateId"),$var);
	}
}

#-------------------------------------------------------------------
sub www_view {
	$_[0]->logView() if ($session{setting}{passiveProfilingEnabled});
	my $var;
	$var->{entryId} = $session{form}{entryId} if ($_[0]->canEdit);
	if ($var->{entryId} eq "list" && $_[0]->canEdit) {
		return $_[0]->processTemplate($_[0]->get("listTemplateId"),$_[0]->getListTemplateVars,"DataForm/List");
	}
	# add Tab StyleSheet and JavaScript
	WebGUI::Style::setLink('/extras/tabs/tabs.css', {"type"=>"text/css"});
	WebGUI::Style::setScript('/extras/tabs/tabs.js', {"language"=>"JavaScript"});
	$var = $_[1] || $_[0]->getRecordTemplateVars($var);
	return $_[0]->processTemplate($_[0]->get("templateId"),$var);
}


1;


