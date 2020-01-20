/*
       Copyright 2009 Carsten Czarski


Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

set define '^'
set verify off
set serveroutput on

prompt >> This script connects to a mail server with the specified login credentials.
prompt >> After connection it opens the mailbox folder "INBOX"
prompt >>
accept MAILSERV                prompt '>> Mailserver                           [mail.domain.de] '
accept MAILPORT default '143'  prompt '>> Mailserver port (pop3=110|imap=143)             [143] '
accept MAILPROT default 'imap' prompt '>> Mailserver protocol (pop3|imap)                [imap] '
accept MAILUSER                prompt '>> Mailbox username                                   [] '
accept MAILPASS                prompt '>> Mailbox password                                   [] '
prompt 

begin
  mail_client.connect_server(
    p_hostname => '^MAILSERV.',
    p_port     => ^MAILPORT.,
    p_protocol => mail_client.protocol_^MAILPROT.,
    p_userid   => '^MAILUSER.',
    p_passwd   => '^MAILPASS.',
    p_ssl      => false
  );
  dbms_output.put_line('Connected to ^MAILSERV.:^MAILPORT using the ^MAILPROT. protocol.');
  mail_client.open_inbox;
  dbms_output.put_line('Mailbox successfully opened.');
  dbms_output.put_line('The INBOX folder contains '||mail_client.get_message_count||' messages.');
end;
/
