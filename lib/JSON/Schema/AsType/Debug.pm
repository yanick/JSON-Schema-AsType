package JSON::Schema::AsType::Debug;

use base 'Exporter::Tiny';
use String::Flogger qw/ flog /;
use Term::ANSIColor;

our @EXPORT = qw/ debug /;

use 5.42.0;

sub debug(@msg) {
    return;
	my( $package, $filename, $line,$subroutine ) = caller(0);
	warn 
		color('red'), flog([ '=== %s l%s ===', $package, $line]),"\n",
		color('blue'), flog(\@msg),color('reset'),"\n";
}


