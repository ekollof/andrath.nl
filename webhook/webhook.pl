#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket::INET;
use Digest::SHA qw(hmac_sha256_hex);
use POSIX qw(strftime setsid);

# Configuration file
my $config_file = "/etc/webhook.conf";
my $log_file = "/var/log/webhook.log";

# Daemonize
daemonize() unless $ENV{DEBUG};

# Load config
my %sites;
open my $fh, '<', $config_file or die "Cannot open $config_file: $!";
while (<$fh>) {
    chomp;
    next if /^#/ or /^\s*$/;
    my ($secret, $user, $workdir, $build_cmd) = split /\s+/, $_, 4;
    $sites{$secret} = { user => $user, workdir => $workdir, build_cmd => $build_cmd };
}
close $fh;

# Create socket
my $socket = IO::Socket::INET->new(
    LocalPort => 8080,
    Proto     => 'tcp',
    Listen    => 5,
    ReuseAddr => 1,
) or die "Cannot create socket: $!";

log_msg("Webhook server started on port 8080");

while (my $client = $socket->accept()) {
    $client->autoflush(1);
    my $request = "";
    my $signature = "";

    # Read HTTP request headers
    my $start_time = time();
    while (my $line = <$client>) {
        if (defined $line) {
            $request .= $line;
            last if $line =~ /^\r\n$/;
        } else {
            log_msg("Failed to read headers from client: $!");
            last;
        }
    }
    log_msg("Headers read in " . (time() - $start_time) . " seconds");
    log_msg("Full request headers:\n" . ($request // "No headers received"));

    # Extract signature
    if ($request =~ /^X-Hub-Signature-256:\s*sha256=([a-f0-9]+)$/mi) {
        $signature = $1;
    } elsif ($request =~ /X-Hub-Signature-256:\s*sha256=([a-f0-9]+)/i) {
        $signature = $1;
    } else {
        log_msg("No X-Hub-Signature-256 found in headers");
    }

    # Respond immediately if signature present
    my $matched = 0;
    my $response_body = "Build triggered\n";
    my $response_length = length($response_body);
    if ($signature && grep { exists $sites{$_} } keys %sites) {
        $matched = 1;
        print $client "HTTP/1.1 200 OK\r\n";
        print $client "Content-Type: text/plain\r\n";
        print $client "Content-Length: $response_length\r\n";
        print $client "Connection: close\r\n";
        print $client "\r\n";
        print $client $response_body;
        $client->flush();
        log_msg("Response sent to client in " . (time() - $start_time) . " seconds");
    }

    # Fork to process payload and build
    my $pid = fork();
    if (!defined $pid) {
        log_msg("Fork failed: $!");
        close $client;
        next;
    } elsif ($pid == 0) {  # Child process
        # Read payload directly from $client (no dup needed)
        local $/ = undef;
        my $payload = <$client> // "";
        log_msg("Payload read, length=" . length($payload));
        close $client;  # Child closes after reading

        # Validate HMAC
        my $child_matched = 0;
        for my $secret (keys %sites) {
            my $computed_hmac = hmac_sha256_hex($payload, $secret);
            if ($signature eq $computed_hmac) {
                my $user = $sites{$secret}->{user};
                my $workdir = $sites{$secret}->{workdir};
                my $build_cmd = $sites{$secret}->{build_cmd};
                log_msg("Signature match for secret=$secret, user=$user, workdir=$workdir, cmd=$build_cmd");

                my $cmd = "cd '$workdir' && git pull && $build_cmd";
                my $result = system("doas -u $user sh -c \"$cmd\" >> $log_file 2>&1");
                if ($result == 0) {
                    log_msg("Build succeeded for $user in $workdir");
                } else {
                    log_msg("Build failed for $user in $workdir with exit code $result");
                }
                $child_matched = 1;
                last;
            }
        }
        unless ($child_matched) {
            log_msg("No signature match in child for: $signature");
        }
        exit 0;
    }

    # Parent: Handle no match and close
    unless ($matched) {
        print $client "HTTP/1.1 403 Forbidden\r\n";
        print $client "Content-Type: text/plain\r\n";
        print $client "Content-Length: 16\r\n";
        print $client "Connection: close\r\n";
        print $client "\r\n";
        print $client "Invalid signature\n";
        $client->flush();
    }
    close $client;  # Parent closes after fork
}

sub daemonize {
    fork and exit;
    setsid or die "Can't start a new session: $!";
    fork and exit;
    chdir '/' or die "Can't chdir to /: $!";
    open STDIN, '/dev/null' or die "Can't redirect STDIN: $!";
    open STDOUT, '>>', $log_file or die "Can't redirect STDOUT: $!";
    open STDERR, '>>', $log_file or die "Can't redirect STDERR: $!";
}

sub log_msg {
    my ($msg) = @_;
    open my $log, '>>', $log_file or warn "Cannot open log: $!";
    print $log strftime("%Y-%m-%d %H:%M:%S", gmtime) . " - $msg\n";
    close $log;
}
