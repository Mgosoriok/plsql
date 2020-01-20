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

col subject format a35
col sender format a30
set pages 20

prompt Only show unread messages ... 

begin
  mail_filter.clear_filters;
  mail_filter.add_seen_filter(false);
end;
/

select msg_number, subject, sender, message_size from table(mail_client.get_mail_headers());

