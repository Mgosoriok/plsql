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

set long 20000

accept MSGNO prompt '>> Message Number                     ' 

set lines 80

col partindex format a10
col content_type format a30
col content_disposition format a20

select 
  partindex, 
  filename,
  substr(content_type, 1, instr(content_type, ';')-1) content_type, 
  content_disposition,
  part_size
from table(mail_client.get_message(^MSGNO.).get_structure())
/
