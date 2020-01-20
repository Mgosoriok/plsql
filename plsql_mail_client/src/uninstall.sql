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
 * Package: PL/SQL MAIL_CLIENT
 * Script:  Deinstallation script
 * Author:  Carsten Czarski [carsten.czarski@gmx.de]
 * Version  1.1.5 (20161202)
 */

/*
 * Drop objects ...
 */


drop package mail_filter
/
drop package mail_client
/

drop type mail_ct
/
drop type mail_t
/

drop type mail_header_ct
/
drop type mail_header_t
/

drop type mail_part_ct
/
drop type mail_part_t
/

drop type mail_array_ct
/

drop type mail_addr_ct
/
drop type mail_addr_t
/

drop java source "MailHandler"
/

/*
 * drop the public synonyms 
 */

drop public synonym mail_t 
/

drop public synonym mail_ct 
/

drop public synonym mail_part_t 
/

drop public synonym mail_part_ct 
/

drop public synonym mail_header_t 
/

drop public synonym mail_header_ct 
/

drop public synonym mail_array_ct
/

drop public synonym mail_client 
/

drop public synonym "MailHandlerImpl" 
/

drop public synonym mail_filter
/

drop public synonym mail_addr_t
/

drop public synonym mail_addr_ct
/
