package WebGUI::Wobject::DownloadManager;

#-------------------------------------------------------------------
# WebGUI is Copyright 2001-2002 Plain Black LLC.
#-------------------------------------------------------------------
# Please read the legal notices (docs/legal.txt) and the license
# (docs/license.txt) that came with this distribution before using
# this software.
#-------------------------------------------------------------------
# http://www.plainblack.com                     info@plainblack.com
#-------------------------------------------------------------------

use strict;
use Tie::CPHash;
use WebGUI::DateTime;
use WebGUI::HTMLForm;
use WebGUI::Icon;
use WebGUI::International;
use WebGUI::Paginator;
use WebGUI::Privilege;
use WebGUI::Search;
use WebGUI::Session;
use WebGUI::SQL;
use WebGUI::URL;
use WebGUI::Utility;
use WebGUI::Wobject;

our @ISA = qw(WebGUI::Wobject);
our $namespace = "DownloadManager";
our $name = WebGUI::International::get(1,$namespace);

#-------------------------------------------------------------------
# example: sortByColumn(columnToSort,columnLabel);
sub sortByColumn {
        my ($output);
        $output = '<a href="'.WebGUI::URL::append($_[2],'sort='.$_[0].'&sortDirection=');
        if ($session{form}{sortDirection} eq "asc") {
                $output .= "desc";
        } else {
                $output .= "asc";
        }
        $output .= '">'.$_[1].'</a>';
        if ($session{form}{sort} eq $_[0]) {
                if ($session{form}{sortDirection} eq "desc") {
                        $output .= ' <img src="'.$session{config}{extras}.'/desc.gif">';
                } else {
                        $output .= ' <img src="'.$session{config}{extras}.'/asc.gif">';
                }
        }
        return $output;
}



#-------------------------------------------------------------------
sub _reorderDownloads {
        my ($sth, $i, $did);
        $sth = WebGUI::SQL->read("select downloadId from DownloadManager_file where wobjectId=$_[0] order by sequenceNumber");
        while (($did) = $sth->array) {
                WebGUI::SQL->write("update DownloadManager_file set sequenceNumber='$i' where downloadId=$did");
                $i++;
        }
        $sth->finish;
}

#-------------------------------------------------------------------
sub duplicate {
        my ($file, $w, %row, $sth, $newDownloadId);
	tie %row, 'Tie::CPHash';
        $w = $_[0]->SUPER::duplicate($_[1]);
        $w = WebGUI::Wobject::DownloadManager->new({wobjectId=>$w,namespace=>$namespace});
        $w->set({
		paginateAfter=>$_[0]->get("paginateAfter"),
		displayThumbnails=>$_[0]->get("displayThumbnails")
		});
        $sth = WebGUI::SQL->read("select * from DownloadManager_file where wobjectId=".$_[0]->get("wobjectId"));
        while (%row = $sth->hash) {
                $newDownloadId = getNextId("downloadId");
		$file = WebGUI::Attachment->new($row{downloadFile},$_[0]->get("wobjectId"),$row{downloadId});
		$file->copy($w->get("wobjectId"),$newDownloadId);
                $file = WebGUI::Attachment->new($row{alternateVersion1},$_[0]->get("wobjectId"),$row{downloadId});
                $file->copy($w->get("wobjectId"),$newDownloadId);
                $file = WebGUI::Attachment->new($row{alternateVersion2},$_[0]->get("wobjectId"),$row{downloadId});
                $file->copy($w->get("wobjectId"),$newDownloadId);
                WebGUI::SQL->write("insert into DownloadManager_file values ($newDownloadId, ".$w->get("wobjectId").", ".
			quote($row{fileTitle}).", ".quote($row{downloadFile}).", $row{groupToView}, ".
			quote($row{briefSynopsis}).", $row{dateUploaded}, $row{sequenceNumber}, ".
			quote($row{alternateVersion1}).", ".quote($row{alternateVersion2}).")");
        }
	$sth->finish;
}

#-------------------------------------------------------------------
sub purge {
	WebGUI::SQL->write("delete from DownloadManager_file where wobjectId=".$_[0]->get("wobjectId"));
	$_[0]->SUPER::purge();
}

#-------------------------------------------------------------------
sub set {
        $_[0]->SUPER::set($_[1],[qw(paginateAfter displayThumbnails)]);
}

#-------------------------------------------------------------------
sub www_deleteFile {
	my ($delete);
        if (WebGUI::Privilege::canEditPage()) {
		if ($session{form}{alt} == 1) {
			$delete = "alternateVersion1";
		} elsif ($session{form}{alt} == 2) {
			$delete = "alternateVersion2";
		} else {
			$delete = "downloadFile";
		}
                WebGUI::SQL->write("update DownloadManager_file set $delete='' where downloadId=$session{form}{did}");
                return $_[0]->www_editDownload();
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_deleteDownload {
        if (WebGUI::Privilege::canEditPage()) {
		return $_[0]->confirm(WebGUI::International::get(12,$namespace),
			WebGUI::URL::page('func=deleteDownloadConfirm&wid='.$session{form}{wid}.'&did='.$session{form}{did}));
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_deleteDownloadConfirm {
        my ($output, $file);
        if (WebGUI::Privilege::canEditPage()) {
                $file = WebGUI::Attachment->new("",$session{form}{wid},$session{form}{did});
                $file->deleteNode;
		$_[0]->deleteCollateral("DownloadManager_file","downloadId",$session{form}{did});
                _reorderDownloads($session{form}{wid});
                return "";
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_download {
	my (%download, $file);
	tie %download,'Tie::CPHash';
	%download = WebGUI::SQL->quickHash("select * from DownloadManager_file where downloadId=$session{form}{did}");
	if (WebGUI::Privilege::isInGroup($download{groupToView})) {
		if ($session{form}{alternateVersion} == 1) {
                        $file = WebGUI::Attachment->new($download{alternateVersion1},
                                $session{form}{wid},
                                $session{form}{did});
		} elsif ($session{form}{alternateVersion} == 2) {
                        $file = WebGUI::Attachment->new($download{alternateVersion2},
                                $session{form}{wid},
                                $session{form}{did});
		} else {
			$file = WebGUI::Attachment->new($download{downloadFile},
				$session{form}{wid},
				$session{form}{did});
		}
		$session{header}{redirect} = WebGUI::Session::httpRedirect($file->getURL);
		return "";
	} else {
		return WebGUI::Privilege::insufficient();
	}
}

#-------------------------------------------------------------------
sub www_edit {
        my ($output, $f, $paginateAfter, $proceed);
        if (WebGUI::Privilege::canEditPage()) {
                if ($_[0]->get("wobjectId") eq "new") {
                        $proceed = 1;
                }
                $output .= helpIcon(1,$namespace);
                $output .= '<h1>'.WebGUI::International::get(9,$namespace).'</h1>';
		$paginateAfter = $_[0]->get("paginateAfter") || 50;
		$f = WebGUI::HTMLForm->new;
		$f->integer("paginateAfter",WebGUI::International::get(20,$namespace),$paginateAfter);
                $f->yesNo("displayThumbnails",WebGUI::International::get(21,$namespace),$_[0]->get("displayThumbnails"));
                $f->yesNo("proceed",WebGUI::International::get(22,$namespace),$proceed);
		$output .= $_[0]->SUPER::www_edit($f->printRowsOnly);
                return $output;
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_editSave {
        if (WebGUI::Privilege::canEditPage()) {
		$_[0]->SUPER::www_editSave();
                $_[0]->set({
			paginateAfter=>$session{form}{paginateAfter},
			displayThumbnails=>$session{form}{displayThumbnails}
			});
                if ($session{form}{proceed}) {
                        $_[0]->www_editDownload();
                } else {
                        return "";
                }
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_editDownload {
        my ($output, %download, $f);
        tie %download,'Tie::CPHash';
        if (WebGUI::Privilege::canEditPage()) {
		if ($session{form}{did} eq "") {
			$session{form}{did} = "new";
		} else {
			%download = WebGUI::SQL->quickHash("select * from DownloadManager_file where downloadId='$session{form}{did}'");
		}
                $output .= helpIcon(2,$namespace);
                $output .= '<h1>'.WebGUI::International::get(10,$namespace).'</h1>';
		$f = WebGUI::HTMLForm->new;
                $f->hidden("wid",$_[0]->get("wobjectId"));
                $f->hidden("did",$session{form}{did});
                $f->hidden("func","editDownloadSave");
		$f->text("fileTitle",WebGUI::International::get(5,$namespace),$download{fileTitle});
		if ($download{downloadFile} ne "") {
			$f->readOnly('<a href="'.WebGUI::URL::page('func=deleteFile&wid='.
				$session{form}{wid}.'&did='.$session{form}{did}).'">'.WebGUI::International::get(391).
				'</a>',WebGUI::International::get(6,$namespace));
                } else {
			$f->file("downloadFile",WebGUI::International::get(6,$namespace));
                }
                if ($download{alternateVersion1} ne "") {
			$f->readOnly('<a href="'.WebGUI::URL::page('func=deleteFile&alt=1&wid='.
				$session{form}{wid}.'&did='.$session{form}{did}).'">'.
				WebGUI::International::get(391).'</a>',WebGUI::International::get(17,$namespace));
                } else {
			$f->file("alternateVersion1",WebGUI::International::get(17,$namespace));
                }
                if ($download{alternateVersion2} ne "") {
			$f->readOnly('<a href="'.WebGUI::URL::page('func=deleteFile&alt=2&wid='.
				$session{form}{wid}.'&did='.$session{form}{did}).'">'.
				WebGUI::International::get(391).'</a>',WebGUI::International::get(18,$namespace));
                } else {
			$f->file("alternateVersion2",WebGUI::International::get(18,$namespace));
                }
                $f->text("briefSynopsis",WebGUI::International::get(8,$namespace),$download{briefSynopsis});
                $f->group("groupToView",WebGUI::International::get(7,$namespace),[$download{groupToView}]);
                $f->yesNo("proceed",WebGUI::International::get(22,$namespace));
		$f->submit;
		$output .= $f->print;
                return $output;
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_editDownloadSave {
        my ($file, %files);
        if (WebGUI::Privilege::canEditPage()) {
		$files{downloadId} = $_[0]->setCollateral("DownloadManager_file", "downloadId", {
                        downloadId => $session{form}{did},
                        fileTitle => $session{form}{fileTitle},
                        briefSynopsis => $session{form}{briefSynopsis},
                        dateUploaded => time(),
                        groupToView => $session{form}{groupToView}
                        });
		_reorderDownloads($_[0]->get("wobjectId"));
                $file = WebGUI::Attachment->new("",$session{form}{wid},$session{form}{did});
		$file->save("downloadFile");
		$files{downloadFile} = $file->getFilename;
		$files{fileTitle} = $files{downloadFile} if ($session{form}{fileTitle} eq "");
                $file = WebGUI::Attachment->new("",$session{form}{wid},$session{form}{did});
		$file->save("alternateVersion1");
		$files{alternateVersion1} = $file->getFilename;
                $file = WebGUI::Attachment->new("",$session{form}{wid},$session{form}{did});
		$file->save("alternateVersion2");
		$files{alternateVersion2} = $file->getFilename;
		$_[0]->setCollateral("DownloadManager_file", "downloadId", \%files);
                if ($session{form}{proceed}) {
                        $session{form}{did} = "new";
                        $_[0]->www_editDownload();
                } else {
                        return "";
                }
        } else {
                return WebGUI::Privilege::insufficient();
        }
}

#-------------------------------------------------------------------
sub www_moveDownloadDown {
	$_[0]->moveCollateralDown("DownloadManager_file","downloadId",$session{form}{did});
}

#-------------------------------------------------------------------
sub www_moveDownloadUp {
	$_[0]->moveCollateralUp("DownloadManager_file","downloadId",$session{form}{did});
}

#-------------------------------------------------------------------
sub www_view {
        my ($url, @row, $i, $p, $file, $constraints, $alt1, $numResults, $alt2, $output, $sth, $head, $sql, %download, $flag, $columns);
        tie %download, 'Tie::CPHash';
	$numResults = $session{form}{numResults} || $_[0]->get("paginateAfter") || 25;
	$url = WebGUI::URL::page();
	$url = WebGUI::URL::append($url,"all=$session{form}{all}") if ($session{form}{all});
	$url = WebGUI::URL::append($url,"atLeastOne=$session{form}{atLeastOne}") if ($session{form}{atLeastOne});
	$url = WebGUI::URL::append($url,"without=$session{form}{without}") if ($session{form}{without});
	$url = WebGUI::URL::append($url,"exactPhrase=$session{form}{exactPhrase}") if ($session{form}{exactPhrase});
	$url = WebGUI::URL::append($url,"numResults=$numResults");
        $columns = '<tr><td class="tableHeader">'.sortByColumn("fileTitle",WebGUI::International::get(14,$namespace),$url).
                '</td><td class="tableHeader">'.sortByColumn("briefSynopsis",WebGUI::International::get(15,$namespace),$url).
                '</td><td class="tableHeader">'.sortByColumn("dateUploaded",WebGUI::International::get(16,$namespace),$url).
                '</td></tr>';
	$url = WebGUI::URL::append($url,"sortDirection=$session{form}{sortDirection}") if ($session{form}{sortDirection});
	$url = WebGUI::URL::append($url,"sort=$session{form}{sort}") if ($session{form}{sort});
	$session{form}{sort} = "sequenceNumber" if ($session{form}{sort} eq "");
	$sql = "select * from DownloadManager_file where wobjectId=".$_[0]->get("wobjectId")." ";
	$constraints = WebGUI::Search::buildConstraints([qw(fileTitle downloadFile alternateVersion1 alternateVersion2 briefSynopsis)]);
	$sql .= " and ".$constraints if ($constraints ne "");
	$sql .= " order by $session{form}{sort} ";
	$sql .= $session{form}{sortDirection};
        $output = $_[0]->displayTitle;
        $output .= $_[0]->description;
	$output = $_[0]->processMacros($output);
	if ($session{form}{search}) {
		$output .= WebGUI::Search::form({search=>1});
	} else {
		$head = '<tr><td colspan="3" align="right" class="tableMenu">';
		$head .= '<a href="'.WebGUI::URL::page('search=1').'">'.WebGUI::International::get(364).'</a>';
        	if ($session{var}{adminOn}) {
                	$head .= ' &middot; <a href="'.WebGUI::URL::page('func=editDownload&did=new&wid='.$_[0]->get("wobjectId"))
                        	.'">'.WebGUI::International::get(11,$namespace).'</a>';
        	}
		$head .= '</td></tr>';
	}
	$output .= '<table cellpadding="3" cellspacing="1" border="0" width="100%">'.$head.$columns;
	$sth = WebGUI::SQL->read($sql);
	while (%download = $sth->hash) {
		if (WebGUI::Privilege::isInGroup($download{groupToView})) {
			$file = WebGUI::Attachment->new($download{downloadFile},
				$_[0]->get("wobjectId"), $download{downloadId});
			$row[$i] = '<tr><td class="tableData" valign="top">';
			if ($session{var}{adminOn}) {
				$row[$i] .= deleteIcon('func=deleteDownload&wid='.$_[0]->get("wobjectId").'&did='.$download{downloadId})
					.editIcon('func=editDownload&wid='.$_[0]->get("wobjectId").'&did='.$download{downloadId})
					.moveUpIcon('func=moveDownloadUp&wid='.$_[0]->get("wobjectId").'&did='.$download{downloadId})
					.moveDownIcon('func=moveDownloadDown&wid='.$_[0]->get("wobjectId").'&did='.$download{downloadId})
					.' ';
			}
			$row[$i] .= '<a href="'.WebGUI::URL::page('func=download&wid='.$_[0]->get("wobjectId").
				'&did='.$download{downloadId}).'">'.$download{fileTitle}.'</a>&nbsp;&middot;&nbsp;<a href="'.
				WebGUI::URL::page('func=download&wid='.
				$_[0]->get("wobjectId").'&did='.$download{downloadId}).'"><img src="'.$file->getIcon.
				'" border=0 width=16 height=16 align="middle">'.$file->getType.'/'.$file->getSize.'</a>';
			if ($download{alternateVersion1}) {
                               	$alt1 = WebGUI::Attachment->new($download{alternateVersion1},
					$_[0]->get("wobjectId"), $download{downloadId});
                               	$row[$i] .= ' &middot; <a href="'.WebGUI::URL::page('func=download&wid='.
					$_[0]->get("wobjectId").'&did='.$download{downloadId}.'&alternateVersion=1')
					.'"><img src="'.$alt1->getIcon.'" border=0 width=16 height=16 align="middle">'.
                                       	$alt1->getType.'/'.$alt1->getSize.'</a>';
			}
			if ($download{alternateVersion2}) {
                               	$alt2 = WebGUI::Attachment->new($download{alternateVersion2}, 
					$_[0]->get("wobjectId"), $download{downloadId});
                               	$row[$i] .= ' &middot; <a href="'.WebGUI::URL::page('func=download&wid='.
					$_[0]->get("wobjectId").'&did='.$download{downloadId}.'&alternateVersion=2')
					.'"><img src="'.$alt2->getIcon.'" border=0 width=16 height=16 align="middle">'.
                                       	$alt2->getType.'/'.$alt2->getSize.'</a>';
			}
			$row[$i] .= '</td><td class="tableData" valign="top">';
			if ($_[0]->get("displayThumbnails") && isIn($file->getType, qw(gif jpeg jpg tif tiff png bmp))) {
				$row[$i] .= '<img src="'.$file->getThumbnail.'" border=0 align="middle" hspace="3">';
			}
			$row[$i] .= $download{briefSynopsis}.'</td>'.'<td class="tableData" valign="top">'.
				epochToHuman($download{dateUploaded},"%z").'</td></tr>';
			$flag = 1;
			$i++;
		}
	}
	$sth->finish;
	$output .= '<tr><td class="tableData" colspan="3">'.WebGUI::International::get(19,$namespace).'</td></tr>' unless ($flag);
	$p = WebGUI::Paginator->new($url,\@row,$numResults);
        $output .= $p->getPage($session{form}{pn});
        $output .= '</table>';
        $output .= $p->getBarTraditional($session{form}{pn});
	return $output;
}


1;


