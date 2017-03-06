<?php 
require_once 'Net/DNS2.php';
header("Cache-Control: no-cache, must-revalidate");
header('Content-Encoding: none;');	// For nginx, so we get the progrss bar (disbles gzip output)
$html_header = <<<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<style type="text/css">
.red {background-color: #FF8080; color: #000000;}
.green {background-color: #80FF80; color: #000000;}
.yellow {background-color: #FFFF80; color: #000000;}
.grey {background-color: #808080; color: #000000;}
.bold {background-color: #FFFFFF; font-weight: bold; color: #000000;}
.center {text-align:center;}

<!-- Progress bar from: http://stackoverflow.com/questions/1802734/html-php-progress-bar -->
#barbox_text {
  position: absolute;
  top: 60px;
  left: 50%;
  margin: 0px 0px 0px -150px;
  font-size: 18px;
  text-align: center;
  width: 300px;
}
  #barbox_a {
  position: absolute;
  top: 60px;
  left: 50%;
  margin: 0px 0px 0px -160px;
  width: 304px;
  height: 24px;
  background-color: black;
}
.barbox_per {
  position: absolute;
  top: 60px;
  font-size: 18px;
  left: 50%;
  margin: 1px 0px 0px 150px;
  background-color: #FFFFFF;
}

.barbox_bar {
  position: absolute;
  top: 62px;
  left: 50%;
  margin: 0px 0px 0px -158px;
  width: 0px;
  height: 20px;
  background-color: #0099FF;
}

.barbox_blank {
  background-color: white;
  width: 300px;
}
</style>
</style>
<head>
</head>
<body>
<p>

EOF;
$html_form = <<<EOF
<form enctype="multipart/form-data" name="sites_upload" action="$_SERVER[REQUEST_URI]" method="post" >
<table border="1"> 
<tr>
	<td>Upload list of sites
	<td><input type="file" name="sites">
	<td><input type="submit" value="Submit">

</table>
</form>

EOF;
$html_progress_bar = <<<EOF
<!-- Progress bar from: http://stackoverflow.com/questions/1802734/html-php-progress-bar -->
<div id='barbox_text'>Sites completed:</div>
<div class='barbox_a'     id='barbox_a'></div>
<div class='barbox_blank' id='barbox_blank'></div>
<div class='barbox_bar'   id='barbox_bar'></div>
<div class='barbox_per'   id='barbox_per'>0%</div>


EOF;
function update_progress($percent,$barbox_text) {
  // First let's recreate the percent with
  // the new one:
  //echo "<div class='barbox_per'>{$barbox_text}</div>\n";
  echo "<script type='text/javascript'>document.getElementById('barbox_per').innerHTML = '$barbox_text';</script>\n";

  // Now, output a new 'bar', forcing its width
  // to 3 times the percent, since we have
  // defined the percent bar to be at
  // 300 pixels wide.
  //echo "<div class='barbox_bar' style='width: ", $percent * 3, "px'></div>\n";
  echo "<script type='text/javascript'>document.getElementById('barbox_bar').style.width = '". $percent * 3 ."px';</script>\n";

  // Now, again, force this to be
  // immediately displayed:
  ob_end_flush();
  flush();
}

function hide_progress() {
	print <<<EOF
<script type='text/javascript'>
	//progress_ids = document.getElementsByName('barbox_per');
	//for ( i=0; i<progress_ids.length; i++) {
	//	progress_ids[i].style.display = 'none';
	//}
	//progress_ids = document.getElementsByName('barbox_bar');
	//for ( i=0; i<progress_ids.length; i++) {
	//	progress_ids[i].style.display = 'none';
	//}
	document.getElementById('barbox_text').style.display = 'none';
	document.getElementById('barbox_a').style.display = 'none';
	document.getElementById('barbox_per').style.display = 'none';
	document.getElementById('barbox_bar').style.display = 'none';
	//document.getElementById('barbox_blank').style.display = 'none';

</script>


EOF;
}

$sites_table_head = <<<EOF
<table border="1"> 
<tr>
	<th>Site
	<th>[CNAME...] IP Address
	<th>DNS Domain
	<th>DNS Name Servers
	<th>DNS MX Servers
	<th>Hosted here?

EOF;

$sites_table_footer = <<<EOF
</table>

EOF;
$html_footer = <<<EOF
</table>
</body>
</html>

EOF;
//phpinfo();
// echo $_POST['sites'];
// echo $_FILES['sites']['tmp_name'];
$my_subnets = array(
	'203.15.70.0/25',
	'203.15.70.128/25',
	);

$my_ns_names = array(
	'ns\d.infoxchange.net.au',
	);
$my_mx_names = array(
	'mail.infoxchange.net.au',
	);

$dns_resolvers = array (
	'8.8.8.8',		// Google
	'8.8.4.4',		// Google
	'211.29.132.12',	// Optus
	'198.142.0.51',		// Optus
	'208.67.222.222',	// OpenDNS
	'208.67.220.220',	// OpenDNS
	'203.50.2.71',		// Telstra internet direct
	'139.130.4.4',		// uneeda.telstra.net
	);

$sites_table_head .= "<tr>\n" .
	"\t<td>My Site</td>\n" .
	"\t<td class=\"center\">". implode("\n\t\t<br>",$my_subnets) . "</td>\n" .
	"\t<td>". '&nbsp;' . "</td>\n" .
	"\t<td>". implode("\n\t\t<br>",$my_ns_names) . "</td>\n" .
	"\t<td>". implode("\n\t\t<br>",$my_mx_names) . "</td>\n" .
	"\t<td>". '&nbsp;' . "</td>\n" ;

function ip_in_subnet($client_ip,$subnet_cidr) {
	$client_ip_l = ip2long($client_ip);
	$subnet_cidr_a = preg_split('/\//',$subnet_cidr);
	$subnet_cidr_l = ip2long($subnet_cidr_a[0]);
	$subnet_mask =  0xFFFFFFFF ^ ( 1 << ( 32 - $subnet_cidr_a[1] ) )  - 1;
	//printf("a = %lx  b = %lx  m = %lx\n",$client_ip_l,$subnet_cidr_l,$subnet_mask);
	if ( ( $client_ip_l & $subnet_mask)  == ( $subnet_cidr_l & $subnet_mask ) ) {
		return true;
	} else {
		return false;
	}
}

echo $html_header;
echo $html_form;
echo $html_progress_bar;
// Write header and progress bar to user
flush();

if ( array_key_exists('sites',$_FILES) ) {
	$sites_url = "file://". $_FILES['sites']['tmp_name'];
} elseif ( ! array_key_exists('SERVER_NAME',$_SERVER) ) {
	// $sites_path = dirname($_SERVER[PATH_INFO]) . '/' . 'sites.txt';
	$sites_path = 'sites.txt';
	$sites_url = "file:///" . $_SERVER['PWD'] .'/' . dirname($_SERVER['SCRIPT_NAME']) . '/'. $sites_path;
//} else {
//	$sites_path = dirname($_SERVER['SCRIPT_NAME']) . '/' . 'sites.txt';
//	$sites_url = "http://$_SERVER[SERVER_NAME]/$sites_path";
}

//echo $sites_url;
$sites_str = trim(file_get_contents("$sites_url"));
$sites = array();
$sites_table = array();
$sites_csv = array();
$sites = preg_split('/[\s\r,]+/',$sites_str);
//echo $sites_str;
foreach ( $sites as $ndx => $site ) {
	$sites[$ndx] = preg_replace('/^www\./',"",$site);
}

sort($sites);
// Use Google's DNS servers
$sites_done =0;
foreach ( $sites as $site ) {

	$domain = preg_replace('/^www\./',"",$site);
	if ( $domain == '' || preg_match('/\./',$domain) == 0 ) {
		continue;
	}
	$is_my_ns = 0;
	$site_ns = array();
	$is_my_ip = 0;
	$site_ip = array();
	$is_my_mx = 0;
	$site_mx = array();
	// Roll the resolvers array on each loop
	$dns_tmp = array_shift($dns_resolvers);
	$dns_resolvers[] = $dns_tmp;

	// --------------- NS ---------------------
	$net_dns2_obj = new Net_DNS2_Resolver(array('nameservers' => $dns_resolvers));
	$domain_ns = $domain;
	$domain_ns_found =0;
	while ( preg_match('/\./',$domain_ns) == 1  && $domain_ns != 'au' && $domain_ns != '.' ) {
		//echo "Checking domain ... " . $domain_ns;
		if ( in_array($domain_ns,array('com','com.au','org','org.au','net','net.au','gov','gov.au','asn.au')) ) {
			// This implies there is no name-server for the domain
			// As a last resort, we can try the NS lookup on the parent domain, eg com.au
			// We shouldn't have to, though
			break;
		}
		try {
			$net_dns2_result = $net_dns2_obj->query("$domain_ns",'NS');
			$dns_result = $net_dns2_result->answer;
		} catch(Net_DNS2_Exception $net_dns2_exception) {
			//echo "::query() failed: ", $net_dns2_exception->getMessage(), "\n";
			$dns_result=array();
		}
		//echo "Found ".count($dns_result)."\n";
		foreach ( array_keys($dns_result) as $ndx) {
			if ( $dns_result[$ndx]->type == 'NS' ) {
				$domain_ns_found=1;
				break;
			}
		}
		if ( $domain_ns_found==1 ) {
			break;
		}
		// Not found yet, Check domain above this one
		$domain_ns = preg_replace('/^[^\.]+\./','',$domain_ns);
	}
	//print_r($dns_result);
	foreach ( array_keys($dns_result) as $ndx) {
		if ( $dns_result[$ndx]->type != 'NS' ) {
			continue;
		}
		//print_r($dns_result[$ndx]);
		$site_ns[] = $dns_result[$ndx]->nsdname;
		$my_ns_found = 0;
		foreach( $my_ns_names as $my_ns_name ) {
			if ( preg_match("/^$my_ns_name\$/i",$site_ns[$ndx]) == 1) {
				$my_ns_found = 1;
				break;
			}
		}
		if ( $my_ns_found == 1) {
			$is_my_ns |= 1;
		} else {
			$is_my_ns |= 2;
		}
	}
	sort($site_ns);
	switch ( $is_my_ns ) {
		case 1:
			$is_my_ns_style = 'class="green"';
			$is_my_ns_csv   = 'our_ns';
			break;
		case 2:
			$is_my_ns_style = 'class="red"';
			$is_my_ns_csv   = '-';
			break;
		case 3:
			$is_my_ns_style = 'class="yellow"';
			$is_my_ns_csv   = 'mixed_ns';
			break;
		default:
			$is_my_ns_style = 'class="grey"';
			$is_my_ns_csv   = '-';
			break;
	}
	// --------------- A (IP) ---------------------
	$dns_result=array();
	// $is_my_ns == 0 == no NS result - don't waste time doing more lookups
	//if ( $is_my_ns > 0 ) {
		$net_dns2_obj = new Net_DNS2_Resolver(array('nameservers' => $dns_resolvers));
		try {
			// First try to lookup www.domain
			$net_dns2_result = $net_dns2_obj->query("www.$domain",'A');
			$dns_result = $net_dns2_result->answer;
			$site = "www.$domain";
		} catch(Net_DNS2_Exception $net_dns2_exception) {
			//echo "::query() failed: ", $net_dns2_exception->getMessage(), "\n";
			// Second try to lookup domain (without the www.)
			$dns_result=array();
			try {
				$net_dns2_result = $net_dns2_obj->query("$domain",'A');
				$dns_result = $net_dns2_result->answer;
				$site = "$domain";
			} catch(Net_DNS2_Exception $net_dns2_exception) {
				$dns_result=array();
			}
		}
	//}
	//print_r($dns_result);
	foreach ( array_keys($dns_result) as $ndx) {
		//$site_ip[] = $dns_result[$ndx][ip];
		//echo $dns_result[$ndx]->type;
		if ( $dns_result[$ndx]->type == 'CNAME' ) {
			//$site_ip[] = $dns_result[$ndx]->address;
			$site_ip[] = $dns_result[$ndx]->cname;
			//print_r($dns_result[$ndx]);
			continue;
		} elseif ( $dns_result[$ndx]->type == 'A' ) {
			$site_ip[] = $dns_result[$ndx]->address;
		} else {
			continue;
		}
		$my_ip_found = 0;
		foreach( $my_subnets as $my_subnet_cidr ) {
			if ( ip_in_subnet($site_ip[count($site_ip)-1],$my_subnet_cidr) ) {
				$my_ip_found = 1;
				break;
			}
		}
		if ( $my_ip_found == 1 ) {
			$is_my_ip |= 1;
		} else {
			$is_my_ip |= 2;
		}
	}
	//sort($site_ip);
	switch ( $is_my_ip ) {
		case 1:
			$is_my_ip_style = 'class="green"';
			$is_my_ip_csv   = 'our_web';
			break;
		case 2:
			$is_my_ip_style = 'class="red"';
			$is_my_ip_csv   = '-';
			break;
		case 3:
			$is_my_ip_style = 'class="yellow"';
			$is_my_ip_csv   = 'mixed_web';
			break;
		default:
			$is_my_ip_style = 'class="grey"';
			$is_my_ip_csv   = '-';
			break;
	}
	// --------------- MX ---------------------
	$dns_result=array();
	// $is_my_ns == 0 == no NS result - don't waste time doing more lookups
	//if ( $is_my_ns > 0 ) {
		$net_dns2_obj = new Net_DNS2_Resolver(array('nameservers' => $dns_resolvers));
		try {
			$net_dns2_result = $net_dns2_obj->query("$domain",'MX');
			$dns_result = $net_dns2_result->answer;
		} catch(Net_DNS2_Exception $net_dns2_exception) {
			//echo "::query() failed: ", $net_dns2_exception->getMessage(), "\n";
			$dns_result=array();
		}
	//}
	//print_r($dns_result);
	foreach ( array_keys($dns_result) as $ndx) {
		if ( $dns_result[$ndx]->type != 'MX' ) {
			continue;
		}
		$site_mx[] = $dns_result[$ndx]->exchange;
		$my_mx_found = 0;
		foreach( $my_mx_names as $my_mx_name ) {
			if ( preg_match("/^$my_mx_name\$/i",$site_mx[$ndx]) == 1) {
				$my_mx_found = 1;
				break;
			}
		}
		if ( $my_mx_found == 1 ) {
			$is_my_mx |= 1;
		} else {
			$is_my_mx |= 2;
		}
	}
	sort($site_mx);
	switch ( $is_my_mx ) {
		case 1:
			$is_my_mx_style = 'class="green"';
			$is_my_mx_csv   = 'our_mx';
			break;
		case 2:
			$is_my_mx_style = 'class="red"';
			$is_my_mx_csv   = '-';
			break;
		case 3:
			$is_my_mx_style = 'class="yellow"';
			$is_my_mx_csv   = 'mixed_mx';
			break;
		default:
			$is_my_mx_style = 'class="grey"';
			$is_my_mx_csv   = '-';
			break;
	}
	switch ( $is_my_ip | $is_my_mx | $is_my_ns ) {
		case 1:
			$is_hosted_by_me = "yes";
			if ( $is_my_ip == 0 && $is_my_mx == 1 && $is_my_ns == 1 ) {
				$is_hosted_by_me = "MX only";
			} elseif ( $is_my_ip == 0 && $is_my_mx == 0 && $is_my_ns == 1 ) {
				$is_hosted_by_me = "NS only - unused domain";
			}
			$is_hosted_by_me_style = 'class="green"';
			break;
		case 2:
			$is_hosted_by_me = "no";
			$is_hosted_by_me_style = 'class="red"';
			break;
		case 3:
			$is_hosted_by_me = "partial";
			$is_hosted_by_me_style = 'class="yellow"';
			break;
		default:
			$is_hosted_by_me = "not found";
			$is_hosted_by_me_style = 'class="grey"';
			break;
	}

	//print_r($dns_result);
	$sites_table[] = "<TR>\n";
	$sites_table[] = "\t<TD class=\"bold\">$site</TD>\n";
	$sites_table[] = "\t<TD style=\"text-align:center;font-family:Monospace,Courier\"$is_my_ip_style>".implode("\n<br>",$site_ip). "</TD>\n";
	if ( $domain != $domain_ns && count($site_ns) > 0 ) {
		$sites_table[] = "\t<TD><b>$domain_ns</b> is NS domain for $domain</TD>\n";
	} else {
		$sites_table[] = "\t<TD class=\"bold\">$domain</TD>\n";
	}
	$sites_table[] = "\t<TD $is_my_ns_style>" . implode(" ",$site_ns). "</TD>\n";
	$sites_table[] = "\t<TD $is_my_mx_style>" . implode("\n<br>",$site_mx). "</TD>\n";
	$sites_table[] = "\t<TD style=\"text-align:center\" $is_hosted_by_me_style >".$is_hosted_by_me. "</TD>\n";

	$sites_csv[$site]  = "$site,";
	$sites_csv[$site] .= implode(" ",$site_ip) . ",$is_my_ip_csv,";
	$sites_csv[$site] .= "$domain,";
	$sites_csv[$site] .= implode(" ",$site_ns) . ",$is_my_ns_csv,";
	$sites_csv[$site] .= implode(" ",$site_mx) . ",$is_my_mx_csv,";
	$sites_csv[$site] .= preg_replace('/ /','_',$is_hosted_by_me);

	$sites_done++;

	//if ( ($sites_done-1) % 5 == 4 ) {
		update_progress( floor($sites_done * 100 / count($sites)), "$sites_done(".count($sites).")" );
	//}
}
update_progress(100,"$sites_done finished");
hide_progress();

$this_server = $_SERVER['SERVER_NAME'];
if ( $_SERVER["SERVER_PORT"] != 80 && $_SERVER["SERVER_PORT"] != 443 ) {
	$this_server .= ":". $_SERVER["SERVER_PORT"];
}
$uri = $_SERVER['REQUEST_URI'];
if ( preg_match('/\/$/',$uri ) ) {
	$uri .= 'dnsxref';
}
$html_url = 'http://' .$this_server. $uri;
$html_url = preg_replace('/\.php$/','',$html_url);
$html_url .= '.html';
$html_filename = $_SERVER['SCRIPT_FILENAME'];
$html_filename = preg_replace('/\.php$/','',$html_filename);
$html_filename .= '.html';
if ( $sites_done > 0 ) {
	$html_fh = fopen($html_filename,'w');
	if ( $html_fh ) {
		fwrite($html_fh,$html_header);
		fwrite($html_fh,$sites_table_head);
		foreach ( $sites_table as $tr ) {
			fwrite($html_fh,$tr);
		}
		fwrite($html_fh,$sites_table_footer);
		fwrite($html_fh,$html_footer);

		fclose($html_fh);
		echo '<p>Saved HTML output to <A href='.$html_url.'>'.$html_url."</A>\n";
	} else {
		$html_fh_error = error_get_last();
		echo "Could not open $html_filename: ".$html_fh_error['message']."\n";
	}
} else {
		echo '<p>Output will be saved to <A href='.$html_url.'>'.$html_url."</A>\n";
}

// CSV output
// Site , CNAME IP... , our_web or -, DNS_Domain , ns1 ns2 ... , our_dns or - , mx1 mx2 ... , our_mx or - , yes/no/partial/not found
$csv_header = '"Site","CNAME/IP","our_web?","DNS_Domain","DNS Servers","our_ns?","Mail Servers","our_mx?","IXA Hosted"'."\n";
$csv_filename = preg_replace('/\.php$/','',$_SERVER['SCRIPT_FILENAME']);
$csv_filename .= '.csv';
$csv_url = 'http://' . $this_server . $uri;
$csv_url = preg_replace('/\.php$/','',$csv_url);
$csv_url .= '.csv';
if ( $sites_done > 0 ) {
	$csv_fh = fopen($csv_filename,'w');
	if ( $csv_fh ) {
		fwrite($csv_fh,$csv_header);
		foreach ( $sites_csv as $line ) {
			fwrite($csv_fh,$line."\n");
		}
		fclose($csv_fh);
		echo '<p>Saved CSV output to <A href='.$csv_url.'>'.$csv_url."</A>\n";
	} else {
		$csv_fh_error = error_get_last();
		echo "Could not open $csv_filename: ".$csv_fh_error['message']."\n";
	}
} else {
		echo '<p>CSV file will be saved to <A href='.$csv_url.'>'.$csv_url."</A>\n";
}

echo $sites_table_head;
foreach ( $sites_table as $tr ) {
	echo $tr;
}
echo $sites_table_footer;
echo $html_footer;
?>
