#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
#       sshpt.py
#
#       Copyright 2011 Dan McDougall <YouKnowWho@YouKnowWhat.com>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; Version 3 of the License
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, the license can be downloaded here:
#
#       http://www.gnu.org/licenses/gpl.html

# TODO:  Add the ability to have host-specific usernames/passwords in the hostlist file
# TODO:  Add the ability to pass command line arguments to uploaded/executed files
# TODO:  Add stderr handling
# TODO:  Add ability to specify the ownership and permissions of uploaded files (when sudo is used)
# TODO:  Add logging using the standard module
# TODO:  Add the ability to specify a host list on the command line.  Something like '--hosts="host1:host2:host3"'

# Docstring:
"""
SSH Power Tool (SSHPT): This program will attempt to login via SSH to a list of servers supplied in a text file (one host per line).  It supports multithreading and will perform simultaneous connection attempts to save time (10 by default).  Results are output to stdout in CSV format and optionally, to an outfile (-o).

If no username and/or password are provided as command line arguments or via a credentials file the program will prompt for the username and password to use in the connection attempts.

This program is meant for situations where shared keys are not an option.  If all your hosts are configured with shared keys for passwordless logins you don't need the SSH Power Tool.
"""

# Meta
__version__ = '1.2.0'
__license__ = "GNU General Public License (GPL) Version 3"
__version_info__ = (1, 2, 0)
__author__ = 'Dan McDougall <YouKnowWho@YouKnowWhat.com>'

# Import built-in Python modules
import getpass, threading, Queue, sys, os, re, datetime
from optparse import OptionParser
from time import sleep
import select

# Import 3rd party modules
try:
    import paramiko
except:
    print("ERROR: The Paramiko module required to use sshpt.")
    print("Download it here: http://www.lag.net/paramiko/")
    exit(1)

def normalizeString(string):
    """Removes/fixes leading/trailing newlines/whitespace and escapes double quotes with double quotes (to comply with CSV format)"""
    string = re.sub(r'(\r\n|\r|\n)', '\n', string) # Convert all newlines to unix newlines
    string = string.strip() # Remove leading/trailing whitespace/blank lines
    srting = re.sub(r'(")', '""', string) # Convert double quotes to double double quotes (e.g. 'foo "bar" blah' becomes 'foo ""bar"" blah')
    return string

class GenericThread(threading.Thread):
    """A baseline thread that includes the functions we want for all our threads so we don't have to duplicate code."""
    def quit(self):
        self.quitting = True

class OutputThread(GenericThread):
    """This thread is here to prevent SSHThreads from simultaneously writing to the same file and mucking it all up.  Essentially, it allows sshpt to write results to an outfile as they come in instead of all at once when the program is finished.  This also prevents a 'kill -9' from destroying report resuls and also lets you do a 'tail -f <outfile>' to watch results in real-time.

        output_queue: Queue.Queue(): The queue to use for incoming messages.
        verbose - Boolean: Whether or not we should output to stdout.
        outfile - String: Path to the file where we'll store results.
    """
    def __init__(self, output_queue, verbose=True, outfile=None):
        """Name ourselves and assign the variables we were instanciated with."""
        threading.Thread.__init__(self, name="OutputThread")
        self.output_queue = output_queue
        self.verbose = verbose
        self.outfile = outfile
        self.quitting = False

    def printToStdout(self, string):
        """Prints 'string' if self.verbose is set to True"""
        if self.verbose == True:
            print string

    def writeOut(self, queueObj):
        """Write relevant queueObj information to stdout and/or to the outfile (if one is set)"""
        if queueObj['local_filepath']:
            queueObj['commands'] = "sshpt: sftp.put %s %s:%s" % (queueObj['local_filepath'], queueObj['host'], queueObj['remote_filepath'])
        elif queueObj['sudo'] is False:
            if len(queueObj['commands']) > 1: # Only prepend 'index: ' if we were passed more than one command
                queueObj['commands'] = "\n".join(["%s: %s" % (index, command) for index, command in enumerate(queueObj['commands'])])
            else:
                queueObj['commands'] = "".join(queueObj['commands'])
        else:
            if len(queueObj['commands']) > 1: # Only prepend 'index: ' if we were passed more than one command
                queueObj['commands'] = "\n".join(["%s: sudo -u %s %s" % (index, queueObj['run_as'], command) for index, command in enumerate(queueObj['commands'])])
            else:
                queueObj['commands'] = "sudo -u %s %s" % (queueObj['run_as'], "".join(queueObj['commands']))
        if isinstance(queueObj['command_output'], str):
            pass # Since it is a string we'll assume it is already formatted properly
        elif len(queueObj['command_output']) > 1: # Only prepend 'index: ' if we were passed more than one command
            queueObj['command_output'] = "\n".join(["%s: %s" % (index, command) for index, command in enumerate(queueObj['command_output'])])
        else:
            queueObj['command_output'] = "\n".join(queueObj['command_output'])
        csv_out = "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"" % (queueObj['host'], queueObj['connection_result'], datetime.datetime.now(), queueObj['commands'], queueObj['command_output'])
        self.printToStdout(csv_out)
        if self.outfile is not None:
            csv_out = "%s\n" % csv_out
            output = open(self.outfile, 'a')
            output.write(csv_out)
            output.close()

    def run(self):
        while not self.quitting:
            queueObj = self.output_queue.get()
            if queueObj == "quit":
                self.quit()
            self.writeOut(queueObj)
            self.output_queue.task_done()

class SSHThread(GenericThread):
    """Connects to a host and optionally runs commands or copies a file over SFTP.
    Must be instanciated with:
      id                    A thread ID
      ssh_connect_queue     Queue.Queue() for receiving orders
      output_queue          Queue.Queue() to output results

    Here's the list of variables that are added to the output queue before it is put():
        queueObj['host']
        queueObj['port']
        queueObj['username']
        queueObj['password']
        queueObj['commands'] - List: Commands that were executed
        queueObj['local_filepath'] - String: SFTP local file path
        queueObj['remote_filepath'] - String: SFTP file destination path
        queueObj['execute'] - Boolean
        queueObj['remove'] - Boolean
        queueObj['sudo'] - Boolean
        queueObj['run_as'] - String: User to execute commands as (via sudo)
        queueObj['connection_result'] - String: 'SUCCESS'/'FAILED'
        queueObj['command_output'] - String: Textual output of commands after execution
    """
    def __init__ (self, id, ssh_connect_queue, output_queue):
        threading.Thread.__init__(self, name="SSHThread-%d" % (id,))
        self.ssh_connect_queue = ssh_connect_queue
        self.output_queue = output_queue
        self.id = id
        self.quitting = False

    def run (self):
        try:
            while not self.quitting:
                queueObj = self.ssh_connect_queue.get()
                if queueObj == 'quit':
                    self.quit()

                # These variable assignments are just here for readability further down
                host = queueObj['host']
                username = queueObj['username']
                password = queueObj['password']
                timeout = queueObj['timeout']
                commands = queueObj['commands']
                local_filepath = queueObj['local_filepath']
                remote_filepath = queueObj['remote_filepath']
                execute = queueObj['execute']
                remove = queueObj['remove']
                sudo = queueObj['sudo']
                run_as = queueObj['run_as']
                port = int(queueObj['port'])

                success, command_output = attemptConnection(
                    host,
                    username,
                    password,
                    timeout,
                    commands,
                    local_filepath,
                    remote_filepath,
                    execute,
                    remove,
                    sudo,
                    run_as,
                    port
                )
                if success:
                    queueObj['connection_result'] = "SUCCESS"
                else:
                    queueObj['connection_result'] = "FAILED"
                queueObj['command_output'] = command_output
                self.output_queue.put(queueObj)
                self.ssh_connect_queue.task_done()
        except Exception, detail:
            print detail
            self.quit()

def startOutputThread(verbose, outfile):
    """Starts up the OutputThread (which is used by SSHThreads to print/write out results)."""
    output_queue = Queue.Queue()
    output_thread = OutputThread(output_queue, verbose, outfile)
    output_thread.setDaemon(True)
    output_thread.start()
    return output_queue

def stopOutputThread():
    """Shuts down the OutputThread"""
    for t in threading.enumerate():
        if t.getName().startswith('OutputThread'):
            t.quit()
    return True

def startSSHQueue(output_queue, max_threads):
    """Setup concurrent threads for testing SSH connectivity.  Must be passed a Queue (output_queue) for writing results."""
    ssh_connect_queue = Queue.Queue()
    for thread_num in range(max_threads):
        ssh_thread = SSHThread(thread_num, ssh_connect_queue, output_queue)
        ssh_thread.setDaemon(True)
        ssh_thread.start()
    return ssh_connect_queue

def stopSSHQueue():
    """Shut down the SSH Threads"""
    for t in threading.enumerate():
        if t.getName().startswith('SSHThread'):
            t.quit()
    return True

def queueSSHConnection(ssh_connect_queue, host, username, password, timeout, commands, local_filepath, remote_filepath, execute, remove, sudo, run_as, port):
    """Add files to the SSH Queue (ssh_connect_queue)"""
    queueObj = {}
    queueObj['host'] = host
    queueObj['username'] = username
    queueObj['password'] = password
    queueObj['timeout'] = timeout
    queueObj['commands'] = commands
    queueObj['local_filepath'] = local_filepath
    queueObj['remote_filepath'] = remote_filepath
    queueObj['execute'] = execute
    queueObj['remove'] = remove
    queueObj['sudo'] = sudo
    queueObj['run_as'] = run_as
    queueObj['port'] = port
    ssh_connect_queue.put(queueObj)
    return True

def paramikoConnect(host, username, password, timeout, port=22):
    """Connects to 'host' and returns a Paramiko transport object to use in further communications"""
    # Uncomment this line to turn on Paramiko debugging (good for troubleshooting why some servers report connection failures)
    #paramiko.util.log_to_file('paramiko.log')
    ssh = paramiko.SSHClient()
    try:
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, port=port, username=username, password=password, timeout=timeout)
    except Exception, detail:
        # Connecting failed (for whatever reason)
        ssh = str(detail)
    return ssh

def sftpPut(transport, local_filepath, remote_filepath):
    """Uses SFTP to transfer a local file (local_filepath) to a remote server at the specified path (remote_filepath) using the given Paramiko transport object."""
    sftp = transport.open_sftp()
    filename = os.path.basename(local_filepath)
    if filename not in remote_filepath:
        remote_filepath = os.path.normpath(remote_filepath + "/")
    sftp.put(local_filepath, remote_filepath)

def sudoExecute(transport, command, password, run_as='root'):
    """Executes the given command via sudo as the specified user (run_as) using the given Paramiko transport object.
    Returns stdout, stderr (after command execution)"""
    stdin, stdout, stderr = transport.exec_command("sudo -S -u %s %s" % (run_as, command))
    if stdout.channel.closed is False: # If stdout is still open then sudo is asking us for a password
        stdin.write('%s\n' % password)
        stdin.flush()
    return stdout, stderr

def executeCommand(transport, command, sudo=False, run_as='root', password=None):
    """Executes the given command via the specified Paramiko transport object.  Will execute as sudo if passed the necessary variables (sudo=True, password, run_as).
    Returns stdout (after command execution)"""
    host = transport.get_host_keys().keys()[0]
    if sudo:
        stdout, stderr = sudoExecute(transport=transport, command=command, password=password, run_as=run_as)
    else:
        stdin, stdout, stderr = transport.exec_command(command)
    command_output = stdout.readlines()
    command_output = "".join(command_output)
    return command_output

def attemptConnection(
        host,
        username,
        password,
        timeout=30, # Connection timeout
        commands=False, # Either False for no commnads or a list
        local_filepath=False, # Local path of the file to SFTP
        remote_filepath='/tmp', # Destination path where the file should end up on the host
        execute=False, # Whether or not the SFTP'd file should be executed after it is uploaded
        remove=False, # Whether or not the SFTP'd file should be removed after execution
        sudo=False, # Whether or not sudo should be used for commands and file operations
        run_as='root', # User to become when using sudo
        port=22, # Port to use when connecting
        ):
    """Attempt to login to 'host' using 'username'/'password' and execute 'commands'.
    Will excute commands via sudo if 'sudo' is set to True (as root by default) and optionally as a given user (run_as).
    Returns connection_result as a boolean and command_output as a string."""

    connection_result = True
    command_output = []

    if host != "":
        try:
            ssh = paramikoConnect(host, username, password, timeout, port=port)
            if type(ssh) == type(""): # If ssh is a string that means the connection failed and 'ssh' is the details as to why
                connection_result = False
                command_output = ssh
                return connection_result, command_output
            command_output = []
            if local_filepath:
                remote_filepath = remote_filepath.rstrip('/')
                local_short_filename = local_filepath.split("/")[-1] or "sshpt_temp"
                remote_fullpath = "%s/%s" % (remote_filepath,local_short_filename)
                try:
                    sftpPut(ssh, local_filepath, remote_fullpath)
                except IOError, details: # i.e. permission denied
                    command_output.append(str(details)) # Make sure the error is included in the command output
                if execute:
                    chmod_command = "chmod a+x %s" % remote_fullpath # Make it executable (a+x in case we run as another user via sudo)
                    executeCommand(transport=ssh, command=chmod_command, sudo=sudo, run_as=run_as, password=password)
                    commands = [remote_fullpath,] # The command to execute is now the uploaded file
                else: # We're just copying a file (no execute) so let's return it's details
                    commands = ["ls -l %s" % remote_fullpath,]
            if commands:
                for command in commands: # This makes a list of lists (each line of output in command_output is it's own item in the list)
                    command_output.append(executeCommand(transport=ssh, command=command, sudo=sudo, run_as=run_as, password=password))
            elif commands is False and execute is False: # If we're not given anything to execute run the uptime command to make sure that we can execute *something*
                command_output = executeCommand(transport=ssh, command='uptime', sudo=sudo, run_as=run_as, password=password)
            if local_filepath and remove: # Clean up/remove the file we just uploaded and executed
                rm_command = "rm -f %s" % remote_fullpath
                executeCommand(transport=ssh, command=rm_command, sudo=sudo, run_as=run_as, password=password)

            ssh.close()
            command_count = 0
            for output in command_output: # Clean up the command output
                command_output[command_count] = normalizeString(output)
                command_count = command_count + 1
        except Exception, detail:
            # Connection failed
            #print "Exception: %s" % detail
            connection_result = False
            command_output = detail
            ssh.close()
        return connection_result, command_output

def sshpt(
        hostlist, # List - Hosts to connect to
        username,
        password,
        max_threads=10, # Maximum number of simultaneous connection attempts
        timeout=30, # Connection timeout
        commands=False, # List - Commands to execute on hosts (if False nothing will be executed)
        local_filepath=False, # Local path of the file to SFTP
        remote_filepath="/tmp/", # Destination path where the file should end up on the host
        execute=False, # Whether or not the SFTP'd file should be executed after it is uploaded
        remove=False, # Whether or not the SFTP'd file should be removed after execution
        sudo=False, # Whether or not sudo should be used for commands and file operations
        run_as='root', # User to become when using sudo
        verbose=True, # Whether or not we should output connection results to stdout
        outfile=None, # Path to the file where we want to store connection results
        output_queue=None, # Queue.Queue() where connection results should be put().  If none is given it will use the OutputThread default (output_queue)
        port=22, # Port to use when connecting
        ):
    """Given a list of hosts (hostlist) and credentials (username, password), connect to them all via ssh and optionally:
        * Execute 'commands' on the host.
        * SFTP a file to the host (local_filepath, remote_filepath) and optionally, execute it (execute).
        * Execute said commands or file via sudo as root or another user (run_as).

    If you're importing this program as a module you can pass this function your own Queue (output_queue) to be used for writing results via your own thread (e.g. to record results into a database or something other than CSV).  Alternatively you can just override the writeOut() method in OutputThread (it's up to you =)."""

    if output_queue is None:
        output_queue = startOutputThread(verbose, outfile)
    # Start up the Output and SSH threads
    ssh_connect_queue = startSSHQueue(output_queue, max_threads)

    if not commands and not local_filepath: # Assume we're just doing a connection test
        commands = ['echo CONNECTION TEST',]

    while len(hostlist) != 0: # Only add items to the ssh_connect_queue if there are available threads to take them.
        for host in hostlist:
            if ssh_connect_queue.qsize() <= max_threads:
                queueSSHConnection(ssh_connect_queue, host, username, password, timeout, commands, local_filepath, remote_filepath, execute, remove, sudo, run_as, port)
                hostlist.remove(host)
        sleep(1)
    ssh_connect_queue.join() # Wait until all jobs are done before exiting
    return output_queue

def main():
    """Main program function:  Grabs command-line arguments, starts up threads, and runs the program."""

    # Grab command line arguments and the command to run (if any)
    usage = 'usage: %prog [options] "[command1]" "[command2]" ...'
    parser = OptionParser(usage=usage, version=__version__)
    parser.disable_interspersed_args()
    parser.add_option("-f", "--file", dest="hostfile", default=None, help="Location of the file containing the host list.", metavar="<file>")
    parser.add_option("-S", "--stdin", dest="stdin", default=False, action="store_true", help="Read hosts from standard input")
    parser.add_option("-o", "--outfile", dest="outfile", default=None, help="Location of the file where the results will be saved.", metavar="<file>")
    parser.add_option("-a", "--authfile", dest="authfile", default=None, help="Location of the file containing the credentials to be used for connections (format is \"username:password\").", metavar="<file>")
    parser.add_option("-t", "--threads", dest="max_threads", default=10, type="int", help="Number of threads to spawn for simultaneous connection attempts [default: 10].", metavar="<int>")
    parser.add_option("-p", "--port", dest="port", default=22, help="The port to be used when connecting.  Defaults to 22.", metavar="<port>")
    parser.add_option("-u", "--username", dest="username", default=os.environ['LOGNAME'], help="The username to be used when connecting.  Defaults to the currently logged-in user.", metavar="<username>")
    parser.add_option("-P", "--password", dest="password", default=None, help="The password to be used when connecting (not recommended--use an authfile unless the username and password are transient).", metavar="<password>")
    parser.add_option("-q", "--quiet", action="store_false", dest="verbose", default=True, help="Don't print status messages to stdout (only print errors).")
    parser.add_option("-c", "--copy-file", dest="copy_file", default=None, help="Location of the file to copy to and optionally execute (-x) on hosts.", metavar="<file>")
    parser.add_option("-D", "--dest", dest="destination", default="/tmp/", help="Path where the file should be copied on the remote host (default: /tmp/).", metavar="<path>")
    parser.add_option("-x", "--execute", action="store_true", dest="execute", default=False, help="Execute the copied file (just like executing a given command).")
    parser.add_option("-r", "--remove", action="store_true", dest="remove", default=False, help="Remove (clean up) the SFTP'd file after execution.")
    parser.add_option("-T", "--timeout", dest="timeout", default=30, help="Timeout (in seconds) before giving up on an SSH connection (default: 30)", metavar="<seconds>")
    parser.add_option("-s", "--sudo", action="store_true", dest="sudo", default=False, help="Use sudo to execute the command (default: as root).")
    parser.add_option("-U", "--sudouser", dest="run_as", default="root", help="Run the command (via sudo) as this user.", metavar="<username>")
    
    (options, args) = parser.parse_args()

    # Check to make sure we were passed at least one command line argument
    try:
        sys.argv[1]
    except:
        print "\nError:  At a minimum you must supply an input hostfile (-f) or pipe in the hostlist (--stdin)."
        parser.print_help()
        sys.exit(2)

    commands = False
    return_code = 0

    ## Assume anything passed to us beyond the command line switches are commands to be executed
    if len(args) > 0:
        commands = args

    # Assign the options to more readable variables
    username = options.username
    password = options.password
    port = options.port
    local_filepath = options.copy_file
    remote_filepath = options.destination
    execute = options.execute
    remove = options.remove
    sudo = options.sudo
    max_threads = options.max_threads
    timeout = options.timeout
    run_as = options.run_as
    verbose = options.verbose
    outfile = options.outfile

    if options.hostfile == None and not options.stdin:
        print "Error: You must supply a file (-f <file>) containing the host list to check "
        print "or use the --stdin option to provide them via standard input"
        print "Use the -h option to see usage information."
        sys.exit(2)
        
    if options.hostfile and options.stdin:
        print "Error: --file and --stdin are mutually exclusive.  Exactly one must be provided."
        sys.exit(2)

    if options.outfile is None and options.verbose is False:
        print "Error: You have not specified any mechanism to output results."
        print "Please don't use quite mode (-q) without an output file (-o <file>)."
        sys.exit(2)

    if local_filepath is not None and commands is not False:
        print "Error: You can either run commands or execute a file.  Not both."
        sys.exit(2)

    # Read in the host list to check
    if options.hostfile:
        hostlist = open(options.hostfile).read()
    elif options.stdin:
        # if stdin wasn't piped in, prompt the user for it now
        if not select.select([sys.stdin,],[],[],0.0)[0]:
            sys.stdout.write("Enter list of hosts (one entry per line). ")
            sys.stdout.write("Ctrl-D to end input.\n")
        # in either case, read data from stdin
        hostlist = sys.stdin.read()

    if options.authfile is not None:
        credentials = open(options.authfile).readline()
        username, password = credentials.split(":")
        password = password.rstrip('\n') # Get rid of trailing newline

    # Get the username and password to use when checking hosts
    if username == None:
        username = raw_input('Username: ')
    if password == None:
        password = getpass.getpass('Password: ')

    hostlist_list = []

    try: # This wierd little sequence of loops allows us to hit control-C in the middle of program execution and get immediate results
        for host in hostlist.split("\n"): # Turn the hostlist into an actual list
            if host != "":
                hostlist_list.append(host)
        output_queue = sshpt(hostlist_list, username, password, max_threads, timeout, commands, local_filepath, remote_filepath, execute, remove, sudo, run_as, verbose, outfile, port=port)
        output_queue.join() # Just to be safe we wait for the OutputThread to finish before moving on
    except KeyboardInterrupt:
        print 'caught KeyboardInterrupt, exiting...'
        return_code = 1 # Return code should be 1 if the user issues a SIGINT (control-C)
        # Clean up
        stopSSHQueue()
        stopOutputThread()
        sys.exit(return_code)
    except Exception, detail:
        print 'caught Exception...'
        print detail
        return_code = 2
        # Clean up
        stopSSHQueue()
        stopOutputThread()
        sys.exit(return_code)

if __name__ == "__main__":
    main()
else:
    # This will be executed if sshpt was imported as a module
    pass # Nothing yet
