#!/usr/bin/perl
#
# Haggis Tech Linux Stats Script
# Version:  2.1.0
# Released: 03 October 2013
#
# Copyright (c) 2012-2013, Haggis
# Copyright (c) 2013, xorangekiller
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#  * Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#  * Neither the name of any individual or organization nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

use strict;
use warnings;

use Switch;
use Term::ANSIColor;

###############################################################################
#                               Global Constants                              #
###############################################################################

use constant STATS_NAME         => 'Haggis Stats';
use constant STATS_VERSION      => '2.1.0';
use constant STATS_COPYRIGHT    => 'Copyright (c) 2012-2013 Haggis';
use constant STATS_LICENSE      => 'BSD 3-Clause';

use constant HOSTNAME_FILE  => '/etc/hostname';
use constant PROC_UPTIME    => '/proc/uptime';
use constant PROC_LOADAVG   => '/proc/loadavg';
use constant PROC_MEMINFO   => '/proc/meminfo';
use constant PROC_CPUINFO   => '/proc/cpuinfo';

###############################################################################
#                          Basic Utility Functions                            #
###############################################################################

# Return the input time as a rationally formatted string.
sub fancy_time
{
    my $time = shift or die 'Internal Error: ' . __LINE__ . "\n"; # Input time
    my $color = shift; # Optional identifier color
    my $string = ''; # Rationally formatted output string
    
    if ($time->{years} == 1) { $string = $time->{years} . ' ' . ($color ? colored ('Year', "bold $color") : 'Year') . ', '; }
    elsif ($time->{years} > 1) { $string = $time->{years} . ' ' . ($color ? colored ('Years', "bold $color") : 'Years') . ', '; }
    
    if ($time->{months} == 1) { $string = $string . $time->{months} . ' ' . ($color ? colored ('Month', "bold $color") : 'Month') . ', '; }
    elsif (($time->{months} > 1) or ($time->{months} == 0 and $string)) { $string = $string . $time->{months} . ' ' . ($color ? colored ('Months', "bold $color") : 'Months') . ', '; }
    
    if ($time->{days} == 1) { $string = $string . $time->{days} . ' ' . ($color ? colored ('Day', "bold $color") : 'Day') . ', '; }
    elsif (($time->{days} > 1) or ($time->{days} == 0 and $string)) { $string = $string . $time->{days} . ' ' . ($color ? colored ('Days', "bold $color") : 'Days') . ', '; }
    
    if ($time->{hours} == 1) { $string = $string . $time->{hours} . ' ' . ($color ? colored ('Hour', "bold $color") : 'Hour') . ', '; }
    elsif (($time->{hours} > 1) or ($time->{hours} == 0 and $string)) { $string = $string . $time->{hours} . ' ' . ($color ? colored ('Hours', "bold $color") : 'Hours') . ', '; }
    
    if ($time->{minutes} == 1) { $string = $string . $time->{minutes} . ' ' . ($color ? colored ('Minute', "bold $color") : 'Minute') . ', '; }
    elsif (($time->{minutes} > 1) or ($time->{minutes} == 0 and $string)) { $string = $string . $time->{minutes} . ' ' . ($color ? colored ('Minutes', "bold $color") : 'Minutes') . ', '; }
    
    if ($time->{seconds} == 1) { $string = $string . $time->{seconds} . ' '. ($color ? colored ('Second', "bold $color") : 'Second'); }
    else { $string = $string . $time->{seconds} . ' '. ($color ? colored ('Seconds', "bold $color") : 'Seconds'); }
    
    return $string;
}

# Return the input number rounded to two decimal places if it is a floating point.
sub fancy_round
{
    return sprintf ("%.2f", $_[0]) if ($_[0] =~ /^[0-9]+\.[0-9]+$/);
    return $_[0];
}

# Convert between memory units.
sub conv_unit
{
    my $mem = shift; # Memory
    my $units = shift or die 'Internal Error: ' . __LINE__ . "\n"; # Units
    
    my $new_mem; # Converted memory
    my $new_units; # Converted units
    
    # Get a common baseline by converting any units unconditionally to bytes.
    switch ($units)
    {
        case /^b$/i {}
        case /^Ki{0,1}B$/i { $mem = $mem * 1024; }
        case /^Mi{0,1}B$/i { $mem = $mem * (1024 ** 2); }
        case /^Gi{0,1}B$/i { $mem = $mem * (1024 ** 3); }
        case /^Ti{0,1}B$/i { $mem = $mem * (1024 ** 4); }
        case /^Ei{0,1}B$/i { $mem = $mem * (1024 ** 5); }
        else { die "Unsupported unit: $units\n"; }
    }
    $units = 'b';
    
    # Guess the best unit type to use if none was given (human readable format).
    unless ($new_units = shift)
    {
        if ($mem >= 1024 ** 5) { $new_units = 'EiB'; }
        elsif ($mem >= 1024 ** 4) { $new_units = 'TiB'; }
        elsif ($mem >= 1024 ** 3) { $new_units = 'GiB'; }
        elsif ($mem >= 1024 ** 2) { $new_units = 'MiB'; }
        elsif ($mem >= 1024) { $new_units = 'KiB'; }
        else { $new_units = 'b'; }
    }
    
    # Convert from our baseline to the requested unit type.
    switch ($new_units)
    {
        case /^b$/i { $new_mem = $mem; }
        case /^Ki{0,1}B$/i { $new_mem = $mem / 1024; }
        case /^Mi{0,1}B$/i { $new_mem = $mem / (1024 ** 2); }
        case /^Gi{0,1}B$/i { $new_mem = $mem / (1024 ** 3); }
        case /^Ti{0,1}B$/i { $new_mem = $mem / (1024 ** 4); }
        case /^Ei{0,1}B$/i { $new_mem = $mem / (1024 ** 5); }
        else { $new_mem = $mem; $new_units = $units; }
    }
    
    return ($new_mem, $new_units);
}

###############################################################################
#                        System Information Functions                         #
###############################################################################

# Return the name of the Linux distro we are running.
sub get_distro
{
    my $distro = 'Unknown'; # Distribution name
    
    # The Linux Standard Base is by far the easiest, and most cross-distro, way
    # to determine which Linux distribution we are running. If it is not
    # available, as is commonly the case on RHEL 5 and 6 installations without
    # a GUI, we will try to probe for the release manually. Manual detection is
    # less reliable, but it gives us an advantage in a few edge cases.
    
    if (system ('which lsb_release 1>/dev/null 2>&1') == 0)
    {
        $distro = (qx[lsb_release -i])[0];
        $distro = ($distro =~ /^[A-Za-z0-9\s]+:\s*(.+)/)[0];
        chomp ($distro);
    }
    else
    {
        use Tie::File;
        use Fcntl 'O_RDONLY';
        
        opendir (DIRECTORY_HANDLE, '/etc') or die "/etc: $!\n";
        while (my $file = readdir (DIRECTORY_HANDLE))
        {
            next unless ($file =~ /\w+-release$/);
            $file = '/etc/' . $file;
            
            my @file_array; # Array tied to the file
            
            tie (@file_array, 'Tie::File', $file, mode => O_RDONLY) or die "$file: $!\n";
            for (@file_array)
            {
                my $line = $_; # Copy of the contents of the line in release file
                
                # Although the $line assignment above doesn't make much sense
                # by itself, we need this additional variable because we opened
                # the release file read-only. We potentially need to modify the
                # contents of the line, as below, but we do not want the nasty
                # side-effect of writing those changes back to the file on
                # disk, which is a typical use of Tie::File::tie(). Therefore
                # we use $line a buffer of sorts.
                chomp ($line);
                $line = (/^\w+\s*=\s*(.+)/)[0] if (/^\w+\s*=\s*.+/);
                
                # The most reliable way to determine a distro from the
                # notoriously distro-specific /etc/*-release file is to
                # white-list the distros we know about. This regular expression
                # probes for the subset of the distros print_logo() understands
                # and we can reasonably reliably probe for.
                if (my $tmp = ($line =~ /(Red\sHat|RHEL|CentOS|Fedora|Debian|Ubuntu|LinuxMint|Elementary OS|Arch|SUSE|SLED|SLES)/i)[0])
                {
                    $distro = $tmp;
                    last;
                }
            }
            untie (@file_array);
            
            last unless ($distro eq 'Unknown');
        }
        closedir (DIRECTORY_HANDLE);
    }
    
    return $distro;
}

# Return the description of the distro release we are running.
sub get_release
{
    my $release; # LSB distro release
    
    if (system ('which lsb_release 1>/dev/null 2>&1') == 0)
    {
        $release = (qx[lsb_release -d])[0];
        $release = ($release =~ /^[A-Za-z0-9\s]+:\s*(.+)/)[0];
        chomp ($release);
    }
    else
    {
        $release = get_distro ();
    }
    
    return $release;
}

# Return the system's hostname.
sub get_hostname
{
    my $hostname; # System hostname
    
    if (-r HOSTNAME_FILE)
    {
        use Tie::File;
        use Fcntl 'O_RDONLY';
        
        my @hostname_array; # Array tied to the hostname file
        
        tie (@hostname_array, 'Tie::File', HOSTNAME_FILE, mode => O_RDONLY) or die HOSTNAME_FILE . ": $!\n";
        $hostname = $hostname_array[0];
        chomp ($hostname);
        untie (@hostname_array);
    }
    else
    {
        $hostname = (qx[uname -n])[0];
        chomp ($hostname);
    }
    
    return $hostname;
}

# Return the kernel release information.
sub get_kernel_release
{
    my $release; # Kernel release
    
    $release = (qx[uname -r])[0];
    chomp ($release);
    
    return $release;
}

# Return the system uptime at the time this function is executed.
sub get_system_uptime
{
    use POSIX qw(floor);
    use Tie::File;
    use Fcntl 'O_RDONLY';
    
    my $uptime = {}; # Parsed system uptime
    my $raw_uptime; # Number of seconds the system has been up
    my @uptime_array; # Array tied to the uptime file
    
    tie (@uptime_array, 'Tie::File', PROC_UPTIME, mode => O_RDONLY) or die PROC_UPTIME . ": $!\n";
    $raw_uptime = (split(/\s+/, $uptime_array[0]))[0];
    untie (@uptime_array);
    
    $uptime->{years} = 0;
    $uptime->{months} = 0;
    $uptime->{days} = 0;
    $uptime->{hours} = 0;
    $uptime->{minutes} = 0;
    $uptime->{seconds} = 0;
    
    $uptime->{years} = floor (($raw_uptime / (365 * 24 * 60 * 60))) if ($raw_uptime > 365 * 24 * 60 * 60);
    $uptime->{months} = floor (($raw_uptime / (30 * 24 * 60 * 60)) % 12) if ($raw_uptime > 30 * 24 * 60 * 60);
    $uptime->{days} = floor (($raw_uptime / (24 * 60 * 60)) % 30) if ($raw_uptime > 24 * 60 * 60);
    $uptime->{hours} = floor (($raw_uptime / (60 * 60)) % 24) if ($raw_uptime > 60 * 60);
    $uptime->{minutes} = floor (($raw_uptime / 60) % 60) if ($raw_uptime > 60);
    $uptime->{seconds} = $raw_uptime % 60;
    
    return $uptime;
}

# Return the system load average.
sub get_load_average
{
    use Tie::File;
    use Fcntl 'O_RDONLY';
    
    my $load = {}; # System load average for the past one, five, and fifteen minutes
    my @loadavg_array; # Array tied to the loadavg file
    
    tie (@loadavg_array, 'Tie::File', PROC_LOADAVG, mode => O_RDONLY) or die PROC_LOADAVG . ": $!\n";
    ($load->{one}, $load->{five}, $load->{fifteen}) = ($loadavg_array[0] =~ /^\s*([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+([0-9]+\.[0-9]+)\s+/);
    untie (@loadavg_array);
    
    return $load;
}

# Return the top running process by real memory usage.
sub get_top_mem
{
    my @top; # Processes sorted from greatest to least by real memory usage
    my $proc; # Process with the greatest memory usage for the current user
    
    @top = qx[ps -eo euid,cmd --sort '-rss' --no-headers];
    for (@top)
    {
        if ((/^\s*([0-9]+)\s+.+/)[0] eq $>)
        {
            $proc = (/^\s*[0-9]+\s+(.+)/)[0];
            last;
        }
    }
    
    return $proc;
}

# Return the current memory usage.
sub get_memory_usage
{
    use Tie::File;
    use Fcntl 'O_RDONLY';
    
    my $mem = {}; # Memory usage
    my @meminfo; # Memory information provided by the kernel
    
    $mem->{ram_total} = 0;
    $mem->{ram_total_units} = 'b';
    $mem->{ram_used} = 0;
    $mem->{ram_used_units} = 'b';
    $mem->{ram_free} = 0;
    $mem->{ram_free_units} = 'b';
    
    $mem->{swap_total} = 0;
    $mem->{swap_total_units} = 'b';
    $mem->{swap_used} = 0;
    $mem->{swap_used_units} = 'b';
    $mem->{swap_free} = 0;
    $mem->{swap_free_units} = 'b';
    
    tie (@meminfo, 'Tie::File', PROC_MEMINFO, mode => O_RDONLY) or die PROC_MEMINFO . ": $!\n";
    for (@meminfo)
    {
        my @tr; # Temporary RAM usage info
        
        if (@tr = /^\s*Mem\s*Total:\s*([0-9]+)\s*([A-Za-z]*)/i)
        {
            $mem->{ram_total} = $tr[0];
            $mem->{ram_total_units} = $tr[1] if ($tr[1]);
        }
        elsif (@tr = /^\s*Mem\s*Free:\s*([0-9]+)\s*([A-Za-z]*)/i)
        {
            $mem->{ram_free} = $tr[0];
            $mem->{ram_free_units} = $tr[1] if ($tr[1]);
        }
        elsif (@tr = /^\s*Swap\s*Total:\s*([0-9]+)\s*([A-Za-z]*)/i)
        {
            $mem->{swap_total} = $tr[0];
            $mem->{swap_total_units} = $tr[1] if ($tr[1]);
        }
        elsif (@tr = /^\s*Swap\s*Free:\s*([0-9]+)\s*([A-Za-z]*)/i)
        {
            $mem->{swap_free} = $tr[0];
            $mem->{swap_free_units} = $tr[1] if ($tr[1]);
        }
    }
    untie (@meminfo);
    
    # Calculate the used RAM based on total and free.
    if ($mem->{ram_total} ne 0)
    {
        if ($mem->{ram_total_units} ne $mem->{ram_free_units})
        {
            ($mem->{ram_total}, $mem->{ram_total_units}) = conv_unit ($mem->{ram_total}, $mem->{ram_total_units}, 'b');
            ($mem->{ram_free}, $mem->{ram_free_units}) = conv_unit ($mem->{ram_free}, $mem->{ram_free_units}, 'b');
        }
        
        $mem->{ram_used} = $mem->{ram_total} - $mem->{ram_free};
        $mem->{ram_used_units} = $mem->{ram_total_units};
    }
    
    # Convert the RAM statistics to human readable units.
    ($mem->{ram_total}, $mem->{ram_total_units}) = conv_unit ($mem->{ram_total}, $mem->{ram_total_units});
    ($mem->{ram_used}, $mem->{ram_used_units}) = conv_unit ($mem->{ram_used}, $mem->{ram_used_units});
    ($mem->{ram_free}, $mem->{ram_free_units}) = conv_unit ($mem->{ram_free}, $mem->{ram_free_units});
    
    # Calculate the used swap based on total and free.
    if ($mem->{swap_total} ne 0)
    {
        if ($mem->{swap_total_units} ne $mem->{swap_free_units})
        {
            ($mem->{swap_total}, $mem->{swap_total_units}) = conv_unit ($mem->{swap_total}, $mem->{swap_total_units}, 'b');
            ($mem->{swap_free}, $mem->{swap_free_units}) = conv_unit ($mem->{swap_free}, $mem->{swap_free_units}, 'b');
        }
        
        $mem->{swap_used} = $mem->{swap_total} - $mem->{swap_free};
        $mem->{swap_used_units} = $mem->{swap_total_units};
    }
    
    # Convert the swap statistics to human readable units.
    ($mem->{swap_total}, $mem->{swap_total_units}) = conv_unit ($mem->{swap_total}, $mem->{swap_total_units});
    ($mem->{swap_used}, $mem->{swap_used_units}) = conv_unit ($mem->{swap_used}, $mem->{swap_used_units});
    ($mem->{swap_free}, $mem->{swap_free_units}) = conv_unit ($mem->{swap_free}, $mem->{swap_free_units});
    
    return $mem;
}

# Return our processor architecture.
sub get_cpu_arch
{
    my $arch; # CPU architecture
    
    if (system ('which arch 1>/dev/null 2>&1') == 0) { $arch = (qx[arch])[0]; }
    elsif (system ('which uname 1>/dev/null 2>&1') == 0) { $arch = (qx[uname -m])[0]; }
    else { $arch = 'Unknown'; }
    
    return $arch;
}

# Return the identification (model name) of the primary processor.
sub get_cpu_identifier
{
    use Tie::File;
    use Fcntl 'O_RDONLY';
    
    my $cpu; # CPU identifier
    my $arch = get_cpu_arch (); # CPU architecture
    my @cpuinfo_array; # Array tied to the cpuinfo file
    
    tie (@cpuinfo_array, 'Tie::File', PROC_CPUINFO, mode => O_RDONLY) or die PROC_CPUINFO . ": $!\n";
    
    # The Linux cpuinfo varies wildly between processor architectures.
    # Therefore the only reliable way to process the identification string is
    # to handle each architecture individually. To limit the number of
    # different computers required to test this function, you should comment at
    # least one example of each case here.
    
    switch ($arch)
    {
        #
        # $arch eq 'x86_64'
        # model name    : Intel(R) Core(TM) i5 CPU       M 560  @ 2.67GHz
        #
        # $arch eq 'i686'
        # model name    : Intel(R) Core(TM)2 Quad CPU           @ 2.40GHz
        #
        case /^(x86_64|i[2-6]86)$/
        {
            for (@cpuinfo_array)
            {
                last if ($cpu = (/^\s*model\s+name\s*:\s*(.+)/i)[0]);
            }
        }
        
        #
        # $arch eq 'armv6l'
        # Processor : ARMv6-compatible processor rev 7 (v6l)
        # BogoMIPS  : 697.95
        # Hardware  : BCM2708
        #
        # $arch eq 'armv7l'
        # Processor : ARMv7 Processor rev 4 (v7l)
        # BogoMIPS  : 1694.10
        # Hardware  : SAMSUNG EXYNOS5 (Flattened Device Tree)
        #
        case /^armv[6-7]l$/
        {
            my $cpu_parts = {}; # Parts of the CPU identification string
            
            for (@cpuinfo_array)
            {
                if ($cpu_parts->{tmp} = (/^\s*Processor\s*:\s*(.+)/i)[0])
                {
                    $cpu_parts->{processor} = $cpu_parts->{tmp} unless ($cpu_parts->{processor});
                }
                elsif ($cpu_parts->{tmp} = (/^\s*BogoMIPS\s*:\s*(.+)/i)[0])
                {
                    $cpu_parts->{bogomips} = $cpu_parts->{tmp} unless ($cpu_parts->{bogomips});
                }
                elsif ($cpu_parts->{tmp} = (/^\s*Hardware\s*:\s*(.+)/i)[0])
                {
                    unless ($cpu_parts->{hardware})
                    {
                        if ($cpu_parts->{tmp} =~ /\(.+\)/)
                        {
                            $cpu_parts->{hardware} = ($cpu_parts->{tmp} =~ /^\s*([A-Za-z0-9\s]+)\s*\(/)[0];
                            chomp ($cpu_parts->{hardware});
                        }
                        else
                        {
                            $cpu_parts->{hardware} = $cpu_parts->{tmp};
                        }
                    }
                }
            }
            
            $cpu = $cpu_parts->{hardware} . ' ' . $cpu_parts->{processor} . ' @ ' . $cpu_parts->{bogomips} . 'MHz';
        }
        
        #
        # $arch eq 'mipsel'
        # cpu model     : MIPS 24Kc V7.4
        # BogoMIPS      : 265.42
        # CPUClock      : 400
        #
        case 'mipsel'
        {
            my $cpu_parts = {}; # Parts of the CPU identification string
            
            for (@cpuinfo_array)
            {
                if ($cpu_parts->{tmp} = (/^\s*cpu\s+model\s*:\s*(.+)/i)[0])
                {
                    $cpu_parts->{processor} = $cpu_parts->{tmp} unless ($cpu_parts->{processor});
                }
                elsif ($cpu_parts->{tmp} = (/^\s*BogoMIPS\s*:\s*(.+)/i)[0])
                {
                    $cpu_parts->{bogomips} = $cpu_parts->{tmp} unless ($cpu_parts->{bogomips});
                }
                elsif ($cpu_parts->{tmp} = (/^\s*CPUClock\s*:\s*(.+)/i)[0])
                {
                    $cpu_parts->{cpuclock} = $cpu_parts->{tmp} unless ($cpu_parts->{cpuclock});
                }
            }
            
            $cpu = $cpu_parts->{processor} . ' @ ' . $cpu_parts->{cpuclock} . 'MHz';
        }
        
        else
        {
            $cpu = 'Unknown';
        }
    }
    
    untie (@cpuinfo_array);
    
    return $cpu;
}

# Return the current screen resolution (X Screen 0).
sub get_screen_resolution
{
    my @xinfo; # xdpyinfo or xrandr output
    my @screen; # Raw screen resolution
    my $res = {}; # Formatted screen resolution
    
    $res->{x} = 0;
    $res->{y} = 0;
    
    if (system ('which xdpyinfo 1>/dev/null 2>&1') == 0)
    {
        @xinfo = qx[xdpyinfo 2>&1];
        for (@xinfo)
        {
            if (@screen = /^\s*dimensions\s*:\s*([0-9]+)\s*x\s*([0-9]+)\s*pixels/i)
            {
                $res->{x} = $screen[0];
                $res->{y} = $screen[1];
            }
        }
    }
    elsif (system ('which xrandr 1>/dev/null 2>&1') == 0)
    {
        @xinfo = qx[xrandr --current 2>&1];
        for (@xinfo)
        {
            if (@screen = /^\s*Screen [0-9]+:.*current\s+([0-9]+)\s*x\s*([0-9]+)/i)
            {
                $res->{x} = $screen[0];
                $res->{y} = $screen[1];
            }
        }
    }
    
    return $res;
}

# Return the desktop environment the user is running.
sub get_desktop_environment
{
    my $desktop_environment = {}; # Desktop environment
    my @proc = qx[ps -eo euid,cmd --no-header]; # Table of running processes
    
    $desktop_environment->{session} = 'Unknown';
    $desktop_environment->{version} = '';
    
    # The DESKTOP_SESSION environment variable is an UNRELIABLE method for
    # determining which desktop environment the user is running. It is tied to
    # the display manager, not inherently to the desktop environment itself.
    # However it is a helpful hint when it is set.
    
    if ($ENV{DESKTOP_SESSION})
    {
        switch ($ENV{DESKTOP_SESSION})
        {
            case /kde|kubuntu/i { $desktop_environment->{session} = 'KDE'; }
            case /cinnamon/i { $desktop_environment->{session} = 'Cinnamon'; }
            case /pantheon/i { $desktop_environment->{session} = 'Pantheon'; }
            case /unity/i { $desktop_environment->{session} = 'Unity'; }
            case /gnome|ubuntu[\-]{0,1}gnome/i { $desktop_environment->{session} = 'GNOME'; }
            case /lxde|lubuntu/i { $desktop_environment->{session} = 'LXDE'; }
            case /xfce|xubuntu/i { $desktop_environment->{session} = 'XFCE'; }
            case /mate/i { $desktop_environment->{session} = 'MATE'; }
            case /openbox/i { $desktop_environment->{session} = 'Openbox'; }
            case /fluxbox/i { $desktop_environment->{session} = 'Fluxbox'; }
        }
    }
    
    if ($desktop_environment->{session} eq 'Unknown')
    {
        for (@proc)
        {
            if ((/^\s*([0-9]+)\s+.+/)[0] eq $>)
            {
                switch ((/^\s*[0-9]+\s+(.+)/)[0])
                {
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*kdeinit/
                    {
                        $desktop_environment->{session} = 'KDE';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*lxsession/
                    {
                        $desktop_environment->{session} = 'LXDE';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*xfce.*session/
                    {
                        $desktop_environment->{session} = 'XFCE';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*cinnamon/
                    {
                        $desktop_environment->{session} = 'Cinnamon';
                        last;
                    }
                    case /^\s*.+--session\s*=\s*pantheon/
                    {
                        $desktop_environment->{session} = 'Pantheon';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*unity-panel/
                    {
                        $desktop_environment->{session} = 'Unity';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*(gnome-session|gnome-shell)/
                    {
                        $desktop_environment->{session} = 'GNOME';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*mate-panel/
                    {
                        $desktop_environment->{session} = 'MATE';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*openbox/
                    {
                        $desktop_environment->{session} = 'Openbox';
                        last;
                    }
                    case /^\s*[A-Za-z0-9\/]{0,1}([A-Za-z0-9\-_]+\/)*fluxbox/
                    {
                        $desktop_environment->{session} = 'Fluxbox';
                        last;
                    }
                }
            }
        }
    }
    
    switch ($desktop_environment->{session})
    {
        case /kde/i
        {
            if (system ('which kde-open 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[kde-open -v])[1] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /cinnamon/i
        {
            if (system ('which cinnamon 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[cinnamon --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /pantheon/i
        {
            # Unlike virtually every other desktop environment in existence,
            # Pantheon does not have an easy way to determine its version using
            # installed binaries (as of Pantheon 1.303, at least). Since
            # Pantheon is developed specifically for Elementary OS, we will use
            # APT to determine its upstream version (to work around this insane
            # limitation).
            
            if (system ('which apt-cache 1>/dev/null 2>&1') == 0 and system ('apt-cache show pantheon-shell 1>/dev/null 2>&1') == 0)
            {
                my @pantheon_shell = qx[apt-cache show pantheon-shell 2>&1];
                for (@pantheon_shell)
                {
                    if (/^\s*Version:\s+([0-9]+\.)+[0-9]+/)
                    {
                        $desktop_environment->{version} = (/Version:\s+(([0-9]+\.)+[0-9]+)/)[0];
                        last;
                    }
                }
            }
        }
        case /unity/i
        {
            if (system ('which unity 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[unity --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /gnome/i
        {
            if (system ('which gnome-session 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[gnome-session --version])[0] =~ /\s+(([0-9]+\.)+[0-9]+)\s+/)[0];
            }
        }
        case /lxde/i
        {
            if (system ('which lxpanel 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[lxpanel --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /xfce/i
        {
            if (system ('which xfce4-session 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[xfce4-session --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /mate/i
        {
            if (system ('which mate-session 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[mate-session --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /openbox/i
        {
            if (system ('which openbox 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[openbox --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
        case /fluxbox/i
        {
            if (system ('which fluxbox 1>/dev/null 2>&1') == 0)
            {
                $desktop_environment->{version} = ((qx[fluxbox --version])[0] =~ /\s+([0-9]+\.+[0-9]+\.+[0-9]+)\s+/)[0];
            }
        }
    }
    
    return $desktop_environment;
}

###############################################################################
#                          Logo Printing Functions                            #
###############################################################################

# Print the Red Hat Enterprise Linux logo and return its primary color.
sub print_rhel_logo
{
    print "\n";
    print '              ' . colored ("............", 'bold red') . "\n";
    print '             ' . colored (";,:::::::,..;;", 'bold red') . "\n";
    print '            ' . colored ("';. ...,:::::::;", 'bold red') . "\n";
    print '         ' . colored (".. '::;::::::::::::,", 'bold red') . "\n";
    print '     ' . colored (".;::::.  ...',;:::::::::.", 'bold red') . "\n";
    print '     ' . colored (".;:::::,..     .:::::::;.;;,.", 'bold red') . "\n";
    print '       ' . colored (".,:::::::;'...'::::::::::::;", 'bold red') . "\n";
    print '          ' . colored (".';:::::::::::::::::::::'", 'bold red') . "\n";
    print '         ' . colored (";NXo", 'black') . colored (" ..';:::::::::::::;'.", 'bold red') . "\n";
    print '      ' . colored (".;'.OMMWMk", 'black') . colored ('..   ..........', 'bold red') . "\n";
    print '  ' . colored (".NWMMMMOl0MMMMMXOkOKXOKKO0.", 'black') . "\n";
    print '   ' . colored (".NMMMMMMMMMMMMMMMWdooNMM0    ..", 'black') . "\n";
    print '     ' . colored ("kMMMMMMMMMMMMMMMMMMMMx .cNMMMO.", 'black') . "\n";
    print '      ' . colored (".OMMMMMMMMMMMMMMMMMMWWMMMMO'", 'black') . "\n";
    print '        ' . colored (".c0MMMMMMMMMMMMMMMMMM0l.", 'black') . "\n";
    print '            ' . colored ("'cx0XWMMMMWX0xl'", 'black') . "\n";
    print "\n";
    return 'red';
}

# Print the CentOS logo and return its primary color.
sub print_centos_logo
{
    print "\n";
    print '                  ' . colored (",", 'white') . colored ("kk", 'yellow') . colored (",", 'white') . "\n";
    print '                ' . colored (";", 'white') . colored ("OOkkOO", 'yellow') . colored (";", 'white') . "\n";
    print '      ' . colored ("cllllllod0", 'white') . colored ("K0Kkk0xk", 'yellow') . colored ("ko:::::::c", 'white') . "\n";
    print '      ' . colored ("O", 'white') . colored ("kkkkk00kkkkX", 'green') . colored ("kkK", 'yellow') . colored (",,,;oo;,,,,", 'magenta') . colored ("O", 'white') . "\n";
    print '      ' . colored ("O", 'white') . colored ("kkkk0KOkkkkX", 'green') . colored ("kkK", 'yellow') . colored (",,,,;xl;;,,", 'magenta') . colored ("O", 'white') . "\n";
    print '     ' . colored (".K", 'white') . colored ("0kkkk0KO0KOX", 'green') . colored ("kkK", 'yellow') . colored ("cdl:do,,,,o", 'magenta') . colored ("K.", 'white') . "\n";
    print '   ' . colored (".", 'white') . colored ("ll0", 'magenta') . colored ("kkkkkkk0KO0N", 'green') . colored ("00X", 'yellow') . colored ("c:dl,,,,,,,", 'magenta') . colored ("Oc", 'blue') . colored ("l.", 'white') . "\n";
    print ' ' . colored ("'", 'white') . colored ("ool,,loooooooood0", 'magenta') . colored ("l''", 'white') . colored ("lOl::::::::::..:l", 'blue') . colored ("'", 'white') . "\n";
    print ' ' . colored (".", 'white') . colored ("ll,,lllllllllldOo", 'magenta') . colored ("''o", 'white') . colored ("0olllllllllc..cl", 'blue') . colored (".", 'white') . "\n";
    print '   ' . colored (".", 'white') . colored ("loO", 'magenta') . colored (".......cl':X", 'blue') . colored ("OON", 'green') . colored ("0OK0kkkkkkk", 'yellow') . colored ("0c", 'blue') . colored ("l.", 'white') . "\n";
    print '     ' . colored (".K", 'white') . colored ("c....cl':l,0", 'blue') . colored ("kkX", 'green') . colored ("0K0OK0kkkk0", 'yellow') . colored ("X.", 'white') . "\n";
    print '      ' . colored ("k", 'white') . colored (".llll'cl'..0", 'blue') . colored ("kkX", 'green') . colored ("kkOK0O0KKKk", 'yellow') . colored ("0", 'white') . "\n";
    print '      ' . colored ("k", 'white') . colored ("....cd'....0", 'blue') . colored ("kkX", 'green') . colored ("kkkkOK0kkkk", 'yellow') . colored ("0", 'white') . "\n";
    print '      ' . colored ("k", 'white') . colored (".....cl'...0", 'blue') . colored ("kkX", 'green') . colored ("kkkOK0kkkkk", 'yellow') . colored ("0", 'white') . "\n";
    print '      ' . colored (":;;;;;;;lx", 'white') . colored ("kx0kk00KO", 'green') . colored ("occcccccc", 'white') . "\n";
    print '                ' . colored (",", 'white') . colored ("kOkkOx", 'green') . colored (",", 'white') . "\n";
    print '                  ' . colored (",", 'white') . colored ("xx", 'green') . colored ("'", 'white') . "\n";
    print "\n";
    return 'magenta';
}

# Print the Fedora logo and return its primary color.
sub print_fedora_logo
{
    print color 'blue';
    print <<'FEDORA_LOGO';

            ,g@@@@@@@@@@@p,
         ,@@@@@@@@@@@D****4@@.
       ,@@@@@@@@@@P`        `%@.
      y@@@@@@@@@@F   ,g@@p.  !3@k
     !@@@@@@@@@@@.  !@@@@@@@@@@@@k
    :@@@@@@@@@@@@   J@@@@@@@@@@@@@L
    J@@@@@@@@@***   `***@@@@@@@@@@)
    J@@@@@@@@@          @@@@@@@@@@)
    J@@@@@@@@@@@@   J@@@@@@@@@@@@@L
    J@@@@@@@@@@@@   J@@@@@@@@@@@@F
    J@@@@@@@@@@@F   {@@@@@@@@@@@F
    J@@@E.  ``*^`   i@@@@@@@@@@B^
    J@@@@@._      ,@@@@@@@@@@P`
    J@@@@@@@@@@@@@@@@@@BP*`

FEDORA_LOGO
    print color 'reset';
    return 'blue';
}

# Print the Debian logo and return its primary color.
sub print_debian_logo
{
    print color 'red';
    print <<'DEBIAN_LOGO';

              _,met$$$$$gg.
           ,g$$$$$$$$$$$$$$$P.
         ,g$$P$$       $$$Y$$.$.
        ,$$P`              `$$$.
       ,$$P       ,ggs.     `$$b:
       d$$`     ,$P$`   .    $$$
       $$P      d$`     ,    $$P
       $$:      $$.   -    ,d$$`
       $$;      Y$b._   _,d$P`
       Y$$.     .`$Y$$$$P$`
       `$$b      $-.__
        `Y$$b
         `Y$$.
           `$$b.
             `Y$$b.
               `$Y$b._
                   `$$$$

DEBIAN_LOGO
    print color 'reset';
    return 'red';
}

# Print the Ubuntu logo and return its primary color.
sub print_ubuntu_logo
{
    print color 'bold bright_red';
    print <<'UBUNTU_LOGO';

               ..''''''..
           .;::::::::::::::;.
        .;::::::::::::::'.':::;.
      .;::::::::;,'..';.   .::::;.
     .:::::::,.,.      ....:::::::.
    .:::::::.   :;::::,.   .:::::::.
    ;::::::   .::::::::::.   ::::::;
    :::.  .'  ::::::::::::...,::::::
    :::.  .'  ::::::::::::...,::::::
    ;::::::   .::::::::::.   ::::::;
    .:::::::.   :,;::;,.   .:::::::.
     .:::::::;.;.      ....:::::::.
       ;::::::::;,'..';.   .::::;
        .;::::::::::::::'.':::;.
           .,::::::::::::::,.
               ...''''...

UBUNTU_LOGO
    print color 'reset';
    return 'bright_red';
}

# Print the Linux Mint logo and return its primary color.
sub print_mint_logo
{
    print color 'bold bright_green';
    print <<'MINT_LOGO';

 .:::::::::::::::::::::::::;,.
 ,0000000000000000000000000000Oxl,
 ,00,                       ..,cx0Oo.
 ,00,       ,,.                  .cO0o
 ,00l,,.   `00;       ..     ..    .k0x
 `kkkkO0l  `00;    ck000Odlk000Oo.  .00c
      d0k  `00;   x0O:.`d00O;.,k00.  x0x
      d0k  `00;  .00x   ,00o   ;00c  d0k
      d0k  `00;  .00d   ,00o   ,00c  d0k
      d0k  `00;  .00d   ,00o   ,00c  d0k
      d0k  `00;   ;;`   .;;.   .cc`  d0k
      d0O  .00d                ...   d0k
      ;00,  :00x:,,,,        .....   d0k
       o0O,  .:dO000k...........     d0k
        :O0x,                        x0k
          :k0Odc,`.................;x00k
            .;lxO0000000000000000000000k
                  ......................

MINT_LOGO
    print color 'reset';
    return 'bright_green';
}

# Print the Elementary OS logo and return its primary color.
sub print_elementary_logo
{
    print color 'white';
    print <<'ELEMENTARY_LOGO';

              .lOXWMMWXOl.
          .lONMMWX0000XWMMNOl.
        cXMM0l,:oOXWWNKxc,l0MMXc
      :NMNl..dWMKo,..,oNMX. .lNMN:
     OMWl  oWMK'       .NMN    lWMO
    0MW'  0MMk          OMM.    'WM0
   lMM:  kMMO          .WMO      dMMl
   NMX  .MMM.         ;WM0      lMMMN
   MMO  'MMW        .OMWo     .0MMWMM
   NMX   NMM;     ;0MWx.    .xMMK.XMN
   lMM:  ,WMWc.cOWMXl     ;OMMK; :MMl
    0MW;';kMMMMMM0; ..,l0WMMO,  ,WM0
     OMMMMMNOkNMMMMMMMMMXx:    oMMO
      :NMMd.   .';:::,.     .lNMN:
        :KMMKo,.        .,oKMMK:
          .ckNMMWXK00KXWMMNkc.
              .lkXWMMWXkl.

ELEMENTARY_LOGO
    print color 'reset';
    return 'white';
}

# Print the Arch Linux logo and return its primary color.
sub print_arch_logo
{
    print color 'bright_blue';
    print <<'ARCH_LOGO';

                    ..                   
                    cc                   
                   :oo:                  
                  ,oooo:                 
                 'oooooo;                
                .oooooooo;               
               ..,looooooo;              
              'ooc;:loooooo;             
             'oooooooooooooo;            
            ,oooooooooooooooo:           
           ;ooooooooooooooooooc          
          :oooooooo:,,:ooooooooc         
         coooooooc      :oooooool.       
        loooooool        coooooool.      
      .loooooooo,        'ooooolc:c.     
     .oooooooooo,        .oooooool;.     
    ,oooooooc;,..         .';cooooool'   
   ;oooc,..                    ..,cooo:  
  :c,.                              .,cc 
 '.                                    .'

ARCH_LOGO
    print color 'reset';
    return 'bright_blue';
}

# Print the openSUSE logo and return its primary color.
sub print_suse_logo
{
    print color 'bold green';
    print <<'SUSE_LOGO';

                       Oxolc:::::ccldxO
                  Odoc:::::::::::::::::::codkO:::clodkO
             0xl:::::::::::::::::::::::::::::::::::::'...:x
          Oo:::::::::::::::::::::::::::::::::::::::p  x....c
        d:::::::::::::::::::::::::::::::::::::::::b     d'.:c
      o:::::::::::::::::::::::::::::::::::::::::::::l  x.,::c
    x::::::::::::::::::::::::::::::::::::::::::::::..:'.,.,cO
   d:::::::::::::::::::::::::::::::::::::::::::::::..;::,.;:l
  x::::::::cc:::::::::::::::::::::::::::::::::::l   d...'::lk
  c::::::c::::c:::::::::::::::::::::::::::::::::::l
  coc:::         o::::::::::::::::::::::::::::::::::::::cox0
  :o:::   0::co    cl::::::cdxkkxoc::::::::l
  :l::   cc  x::x    d::::d         d:::::::0
  ::c:   ccl  c::::   l:::0           d::::::x
  o:::k   c:l   c::     c:o               k:::c
   c:::l       d::                           l:0
    ox::::::::::c
      :Okllxcox

SUSE_LOGO
    print color 'reset';
    return 'green';
}

# Print the Linux logo and return its primary color.
sub print_linux_logo
{
    print "\n";
    print '                 ' . colored (".88888888:.", 'black') . "\n";
    print '                ' . colored ("88888888.88888.", 'black') . "\n";
    print '              ' . colored (".8888888888888888.", 'black') . "\n";
    print '              ' . colored ("888888888888888888", 'black') . "\n";
    print '              ' . colored ("88| _`88|_  `88888", 'black') . "\n";
    print '              ' . colored ("88 88 88 88  88888", 'black') . "\n";
    print '              ' . colored ("88_88_", 'black') . colored ("::", 'yellow') . colored ("_88_", 'black') . colored (":", 'yellow') . colored ("88888", 'black') . "\n";
    print '              ' . colored ("88", 'black') . colored (":::", 'yellow') . colored (",", 'black') . colored ("::", 'yellow') . colored (",", 'black') . colored (":::::", 'yellow') . colored ("8888", 'black') . "\n";
    print '              ' . colored ("88`", 'black') . colored (":::::::::", 'yellow') . colored ("``8888", 'black') . "\n";
    print '             ' . colored (".88  `", 'black') . colored ("::::", 'yellow') . colored ("`    8:88.", 'black') . "\n";
    print '            ' . colored ("8888            `8:888.", 'black') . "\n";
    print '          ' . colored (".8888`             `888888.", 'black') . "\n";
    print '         ' . colored (".8888", 'black') . colored (":..  .::.  ...:", 'bright_black') . colored ("`8888888:.", 'black') . "\n";
    print '        ' . colored (".8888", 'black') . colored (".|     :|     `|::", 'bright_black') . colored ("`88:88888", 'black') . "\n";
    print '       ' . colored (".8888        ", 'black') . colored ("`", 'bright_black') . colored ("         `.888:8888.", 'black') . "\n";
    print '      ' . colored ("888:8         ", 'black') . colored (".", 'bright_black') . colored ("           888:88888", 'black') . "\n";
    print '    ' . colored (".888:88        ", 'black') . colored (".:", 'bright_black') . colored ("           888:88888:", 'black') . "\n";
    print '    ' . colored ("8888888.       ", 'black') . colored ("::", 'bright_black') . colored ("           88:888888", 'black') . "\n";
    print '    ' . colored ("`", 'black') . colored (".::.", 'yellow') . colored ("888.", 'black') . colored ("::", 'bright_black') . colored ("          .88888888", 'black') . "\n";
    print '   ' . colored (".::::::.", 'yellow') . colored ("888.    ", 'black') . colored ("::", 'bright_black') . colored ("         :::", 'yellow') . colored ("`8888`", 'black') . colored (".:.", 'yellow') . "\n";
    print '  ' . colored ("::::::::::.", 'yellow') . colored ("888   ", 'black') . colored ("|", 'bright_black') . colored ("         .::::::::::::", 'yellow') . "\n";
    print '  ' . colored ("::::::::::::.", 'yellow') . colored ("8    ", 'black') . colored ("|", 'bright_black') . colored ("      .:", 'yellow') . colored ("8", 'black') . colored ("::::::::::::.", 'yellow') . "\n";
    print ' ' . colored (".::::::::::::::.        .:", 'yellow') . colored ("888", 'black') . colored (":::::::::::::", 'yellow') . "\n";
    print ' ' . colored (":::::::::::::::", 'yellow') . colored ("88", 'black') . colored (":.", 'yellow') . colored ("__", 'black') . colored ("..:", 'yellow') . colored ("88888", 'black') . colored (":::::::::::`", 'yellow') . "\n";
    print '  ' . colored ("``.:::::::::::", 'yellow') . colored ("88888888888", 'black') . colored (".", 'yellow') . colored ("88", 'black') . colored (":::::::::`", 'yellow') . "\n";
    print '        ' . colored ("``:::_:`", 'yellow') . colored (" -- ", 'bright_black') . colored ("``", 'black') . colored (" -`-` `", 'bright_black') . colored ("`:_::::``", 'yellow') . "\n";
    print "\n";
    return 'yellow';
}

# Determine our Linux distro, print the appropriate logo, and return its primary color.
sub print_logo
{
    switch (get_distro ())
    {
        case /Red\sHat|RHEL/i   { return print_rhel_logo (); }
        case /CentOS/i          { return print_centos_logo (); }
        case /Fedora/i          { return print_fedora_logo (); }
        case /Debian/i          { return print_debian_logo (); }
        case /Ubuntu/i          { return print_ubuntu_logo (); }
        case /LinuxMint/i       { return print_mint_logo (); }
        case /Elementary OS/i   { return print_elementary_logo (); }
        case /Arch/i            { return print_arch_logo (); }
        case /SUSE|SLES|SLED/i  { return print_suse_logo (); }
    }
    
    return print_linux_logo ();
}

###############################################################################
#                                  Actions                                    #
###############################################################################

# Print our help information.
sub print_help
{
    print <<HELP;
Usage: $0 [OPTIONS] ACTION

Print basic system statistics and immortalize those results with a screenshot.

Actions:
    stats               Print system statistics and take a screenshot
    report              Print diagnostic information
    help                Print this help information
    version             Print our version information

Options:
    --no-screenshot     Don't take a screenshot after printing system statistics
    --no-logo           Don't print the logo for your distribution
    --output-dir DIR    Save the screenshot or report to DIR

HELP
}

# Print our version information.
sub print_version
{
    print STATS_NAME . ' ' . STATS_VERSION . "\n";
    print STATS_COPYRIGHT . "\n";
    print 'License: ' . STATS_LICENSE . "\n";
}

# Print diagnostic information.
sub print_report
{
    use POSIX qw(strftime);
    
    my $output_directory = shift or die 'Internal Error: ' . __LINE__ . "\n"; # Directory to which the report should be saved
    my $report_file; # File name for the output file
    my @report_actions; # File and programs to write to $report_file
    
    push (@report_actions, {type => 'program', command => 'lsb_release', arguments => '-i'});
    push (@report_actions, {type => 'program', command => 'lsb_release', arguments => '-d'});
    push (@report_actions, {type => 'program', command => 'lsb_release', arguments => '-a'});
    push (@report_actions, {type => 'program', command => 'uname', arguments => '-n'});
    push (@report_actions, {type => 'program', command => 'uname', arguments => '-r'});
    push (@report_actions, {type => 'program', command => 'uname', arguments => '-m'});
    push (@report_actions, {type => 'program', command => 'uname', arguments => '-a'});
    push (@report_actions, {type => 'program', command => 'arch', arguments => ''});
    push (@report_actions, {type => 'program', command => 'ps', arguments => 'aux'});
    push (@report_actions, {type => 'program', command => 'xdpyinfo', arguments => ''});
    push (@report_actions, {type => 'program', command => 'xrandr', arguments => '--current'});
    push (@report_actions, {type => 'environment', variable => 'HOME'});
    push (@report_actions, {type => 'environment', variable => 'USER'});
    push (@report_actions, {type => 'file', file => HOSTNAME_FILE});
    push (@report_actions, {type => 'file', file => PROC_UPTIME});
    push (@report_actions, {type => 'file', file => PROC_LOADAVG});
    push (@report_actions, {type => 'file', file => PROC_MEMINFO});
    push (@report_actions, {type => 'file', file => PROC_CPUINFO});
    push (@report_actions, {type => 'directory', directory => '/etc', regex => '\w+-release'});
    
    $report_file = $output_directory . '/' . 'stats_report_' . $ENV{USER} . '_' . strftime ("%Y%m%d.%H%M%S", localtime) . '.log';
    open (REPORT_HANDLE, '>', $report_file) or die $report_file . ": $!\n";
    
    print REPORT_HANDLE STATS_NAME . ' ' . STATS_VERSION . "\n";
    print REPORT_HANDLE "\n=== DIAGNOSTIC REPORT ===\n";
    print REPORT_HANDLE "\nYYYY-MM-DD.HH-MM-SS\n";
    print REPORT_HANDLE strftime ("%Y-%m-%d.%H-%M-%S", localtime) . "\n";
    print REPORT_HANDLE "\n";
    
    print REPORT_HANDLE "\n";
    for (0 .. 24) { print REPORT_HANDLE '='; }
    print REPORT_HANDLE "\n\n";
    
    for (@report_actions)
    {
        my %action = %$_;
        
        switch ($action{type})
        {
            case 'program'
            {
                if (system ('which ' . $action{command} . ' 1>/dev/null 2>&1') == 0)
                {
                    if ($action{arguments}) { print REPORT_HANDLE '[' . $action{command} . ' ' . $action{arguments} . "]\n"; }
                    else { print REPORT_HANDLE '[' . $action{command} . "]\n"; }
                    print REPORT_HANDLE qx[$action{command} $action{arguments} 2>&1];
                    print REPORT_HANDLE "\n";
                }
                else
                {
                    print REPORT_HANDLE '[' . $action{command} . "]\n";
                    print REPORT_HANDLE "command not found\n";
                }
            }
            case 'environment'
            {
                print REPORT_HANDLE '[' . $action{type} . ' ' . $action{variable} . "]\n";
                print REPORT_HANDLE $ENV{$action{variable}} . "\n";
            }
            case 'file'
            {
                if (open (FILE_HANDLE, '<', $action{file}))
                {
                    print REPORT_HANDLE '[' . $action{type} . ' ' . $action{file} . "]\n";
                    while (<FILE_HANDLE>)
                    {
                        chomp;
                        print REPORT_HANDLE "$_\n";
                    }
                    print REPORT_HANDLE "\n";
                    close (FILE_HANDLE);
                }
                else
                {
                    print REPORT_HANDLE '[' . $action{type} . ' ' . $action{file} . "]\n";
                    print REPORT_HANDLE "$!\n";
                }
            }
            case 'directory'
            {
                if (opendir (DIRECTORY_HANDLE, $action{directory}))
                {
                    print REPORT_HANDLE '[' . $action{type} . ' ' . $action{directory} . "]\n";
                    while (my $file = readdir (DIRECTORY_HANDLE))
                    {
                        chomp ($file);
                        next unless ($file =~ /$action{regex}/);
                        $file = $action{directory} . '/' . $file;
                        print REPORT_HANDLE $file . "\n";
                        push (@report_actions, {type => 'file', file => $file});
                    }
                    print REPORT_HANDLE "\n";
                    closedir (DIRECTORY_HANDLE);
                }
                else
                {
                    print REPORT_HANDLE '[' . $action{type} . ' ' . $action{directory} . "]\n";
                    print REPORT_HANDLE "$!\n";
                }
            }
            else
            {
                die 'Internal Error: ' . __LINE__ . "\n";
            }
        }
        
        print REPORT_HANDLE "\n";
        for (0 .. 24) { print REPORT_HANDLE '='; }
        print REPORT_HANDLE "\n\n";
    }
    
    close (REPORT_HANDLE);
    print 'Diagnostic report written to ' . $report_file . "\n";
}

# Print system statistics.
sub print_stats
{
    my $color = shift; # Primary color of distro's logo
    my $release = get_release (); # Distribution release
    my $hostname = get_hostname (); # System hostname
    my $uptime = get_system_uptime (); # Current system uptime
    my $cpu = get_cpu_identifier (); # CPU identifier
    my $mem = get_memory_usage (); # Current memory usage
    my $de = get_desktop_environment (); # Current user's desktop environment
    my $kernel = get_kernel_release (); # Kernel release
    my $res = get_screen_resolution (); # Screen resolution
    my $load = get_load_average (); # Load average
    my $top = get_top_mem (); # Top process by memory usage
    
    print colored ("OS:", "bold $color") . "                          " . $release . "\n" if ($release);
    print colored ("Hostname:", "bold $color") . "                    " . $hostname . "\n" if ($hostname);
    print colored ("Uptime:", "bold $color") . "                      " . fancy_time ($uptime, $color) . "\n";
    print colored ("CPU:", "bold $color") . "                         " . $cpu . "\n" unless ($cpu eq 'Unknown');
    print colored ("RAM (total / used):", "bold $color") . "          " . fancy_round ($mem->{ram_total}) . colored ($mem->{ram_total_units}, "bold $color") . ' / ' . fancy_round ($mem->{ram_used}) . colored ($mem->{ram_used_units}, "bold $color") . "\n";
    print colored ("Swap (total / used):", "bold $color") . "         " . fancy_round ($mem->{swap_total}) . colored ($mem->{swap_total_units}, "bold $color") . ' / ' . fancy_round ($mem->{swap_used}) . colored ($mem->{swap_used_units}, "bold $color") . "\n";
    print colored ("Desktop Environment:", "bold $color") . "         " . $de->{session} . ' ' . $de->{version} . "\n" unless ($de->{session} eq 'Unknown');
    print colored ("Logged in as:", "bold $color") . "                " . $ENV{USER} . "\n" if ($ENV{USER});
    print colored ("Kernel:", "bold $color") . "                      " . $kernel . "\n" unless ($kernel eq 'Unknown');
    print colored ("Resolution:", "bold $color") . "                  " . $res->{x} . colored (" x ", "bold $color") . $res->{y} . colored (" pixels", "bold $color") . "\n" unless ($res->{x} == 0);
    print colored ("Load Average:", "bold $color") . "                " . $load->{five} . "\n";
    print colored ("Top Process (by memory use):", "bold $color") . " " . $top . "\n\n" if ($top);
    
    # The easiest way to determine if we are running in a graphical environment
    # without duplicating effort is based on the screen resolution.
    # get_screen_resolution() will set both coordinates to zero if something
    # goes wrong, but just to be safe we will return FALSE (we are not running
    # in a graphical environment) if either is zero.
    return 0 if ($res->{x} == 0 or $res->{y} == 0);
    return 1;
}

# Take a screenshot and save it in the specified directory.
sub print_screenshot
{
    my $output_directory = shift or die 'Internal Error: ' . __LINE__ . "\n"; # Directory to which the screenshot should be saved
    my $color = shift; # Optional identifier color
    my $screenshot_cmd; # Command to take the screenshot
    my $screenshot_file; # File the screenshot will be written to
    
    # There are many utilities to take a screenshot of an X session. Therefore
    # only a limited subset which are likely to be installed on target systems
    # are supported by this script. In the event that more than one supported
    # utility is installed, the one with the greatest preference will be
    # selected.
    if (system ('which scrot 1>/dev/null 2>&1') == 0)
    {
        $screenshot_cmd = 'scrot --silent';
    }
    elsif (system ('which import 1>/dev/null 2>&1') == 0)
    {
        $screenshot_cmd = 'import -window root';
    }
    
    if ($screenshot_cmd)
    {
        use POSIX qw(strftime);
        
        $screenshot_file = $output_directory . '/' . 'screenshot_' . strftime ("%Y%m%d.%H%M%S", localtime) . '.png';
        
        print 'Screenshot being taken..... ' . ($color ? colored ('Smile!!', "bold $color") : 'Smile!!') . "\n";
        sleep (2); # Give the X server time to flush its buffers before the screenshot is taken.
        if (system ($screenshot_cmd . ' ' . $screenshot_file) == 0)
        {
            print 'Screenshot saved as ' . $screenshot_file . "\n\n";
        }
        else
        {
            print STDERR "Screenshot failed!\n\n";
        }
    }
    else
    {
        print 'Screenshot cannot be taken..... ' . ($color ? colored ('scrot', "bold $color") : 'scrot') . " missing!\n\n";
    }
}

###############################################################################
#                                Entry Point                                  #
###############################################################################

# Actions
my $p_stats = 0;
my $p_report = 0;
my $p_help = 0;
my $p_version = 0;

# Options
my $p_screenshot = 1;
my $p_logo = 1;
my $p_output_directory = $ENV{PWD};

# Parse our command-line arguments.
if ($#ARGV >= 1)
{
    while ($#ARGV > 0)
    {
        switch ($_ = shift)
        {
            case '--no-screenshot'
            {
                $p_screenshot = 0;
            }
            case '--no-logo'
            {
                $p_logo = 0;
            }
            case /^--output-dir(=.+){0,1}$/
            {
                if (/--output-dir=/) { $p_output_directory = (/--output-dir=(.+)/)[0]; }
                else { $p_output_directory = shift; }
                
                # Workaround: Since "~" is so commonly used to reference one's
                # home directory, accept it by translating it into the HOME
                # environment variable.
                if ($p_output_directory =~ /^~/)
                {
                    $p_output_directory = ($p_output_directory =~ /^~(.*)/)[0];
                    $p_output_directory = $ENV{HOME} . $p_output_directory;
                }
                
                unless ($p_output_directory and -d $p_output_directory)
                {
                    die die "Invalid OUTPUT_DIRECTORY: $p_output_directory\n";
                }
            }
            else
            {
                die "Invalid OPTION: $_\n";
            }
        }
    }
}
if ($#ARGV >= 0)
{
    for (@ARGV)
    {
        switch ($_)
        {
            case 'stats' { $p_stats = 1; }
            case 'report' { $p_report = 1; }
            case 'help' { $p_help = 1; }
            case 'version' { $p_version = 1; }
            else { die "Invalid ACTION: $_\n"; }
        }
    }
}
else
{
    $p_stats = 1;
}

# Take action!
if ($p_help)
{
    print_help ();
}
elsif ($p_version)
{
    print_version ();
}
elsif ($p_report)
{
    print_report ($p_output_directory);
}
elsif ($p_stats)
{
    my $color = 'black'; # Primary color of distro's logo
    my $is_graphical; # Is X running in the current context?
    
    if ($p_logo == 1) { $color = print_logo (); }
    else { print "\n"; }
    $is_graphical = print_stats ($color);
    print_screenshot ($p_output_directory, $color) if ($p_screenshot == 1 and $is_graphical == 1);
}

exit 0;
