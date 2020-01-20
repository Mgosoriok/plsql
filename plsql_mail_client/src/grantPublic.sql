/*
       Copyright 2010-2013 Carsten Czarski


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

/*
 * Package:       PL/SQL MAIL_CLIENT
 * Script:        Installation script
 * Author:        Carsten Czarski [carsten.czarski@gmx.de]
 * Contributors:  Andre Meier, Christian Haßlbauer, Thomas Schild, Axel Röber
 * Version:       1.1.5 (20161202)
 */



create public synonym mail_t for mail_t
/

create public synonym mail_ct for mail_ct
/

create public synonym mail_part_t for mail_part_t
/

create public synonym mail_part_ct for mail_part_ct
/

create public synonym mail_addr_t for rcpt_addr_t
/

create public synonym mail_addr_ct for mail_addr_ct
/

create public synonym mail_header_t for mail_header_t
/

create public synonym mail_header_ct for mail_header_ct
/

create public synonym mail_client for mail_client
/

create public synonym mail_filter for mail_filter
/

create public synonym mail_array_ct for mail_array_ct
/

create public synonym "MailHandlerImpl" for "MailHandlerImpl"
/

grant execute on mail_client to public
/
grant execute on mail_t to public
/
grant execute on mail_filter to public
/
grant execute on "MailHandlerImpl" to public
/


grant execute on mail_ct to public
/
grant execute on mail_part_t to public
/
grant execute on mail_part_ct to public
/
grant execute on mail_addr_t to public
/
grant execute on mail_addr_ct to public
/
grant execute on mail_header_t to public
/
grant execute on mail_header_ct to public
/
grant execute on mail_array_ct to public
/


