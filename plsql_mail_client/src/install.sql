/*
       Copyright 2010-2016 Carsten Czarski


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
 * Contributors:  Andre Meier, Christian Hasslbauer, Thomas Schild, Axel Röber
 * Version:       1.1.5 (20161202)
 */

set define off

create or replace and compile java source named "MailHandler" as
import java.sql.Connection;
import java.sql.DriverManager;

import java.util.Properties;
import java.util.Vector;

import javax.mail.Folder;
import javax.mail.FetchProfile;
import javax.mail.Message;
import javax.mail.internet.MimeMessage;
import javax.mail.Session;
import javax.mail.Store;
import javax.mail.Flags;
import javax.mail.BodyPart;
import javax.mail.Part;
import javax.mail.Multipart;
import javax.mail.internet.ContentType;
import javax.mail.Header;
import javax.mail.internet.InternetAddress;
import javax.mail.Address;
// import javax.mail.internet.MimeUtility;
import oracle.i18n.net.MimeUtility;
import javax.mail.search.*;
import javax.activation.*;
import javax.mail.util.*;

import java.nio.charset.Charset;

import java.io.*;

import oracle.sql.ARRAY;
import oracle.sql.ArrayDescriptor;
import oracle.sql.STRUCT;
import oracle.sql.CLOB;
import oracle.sql.StructDescriptor;

import oracle.jdbc.*;
import oracle.jdbc2.*;
import oracle.sql.*;
import java.sql.*;
import java.util.*;

import java.math.BigDecimal;

public class MailHandlerImpl implements SQLData {
  static final int TEMPLOB_DURATION = BLOB.DURATION_SESSION;

  static Session oMailSession = null;
  static Store   oMailStore   = null;
  static Folder  oCurrentFolder = null;
  static Vector  oMessageFilters = new Vector();
  static int     iMessageFilterCombination = 0;

  static int     iMessageFetchLimit = -1;

  static boolean bIsConnected = false;

  private        int        iMessageNumber;
  private        String     sSubject;
  private        String     sSender;
  private        String     sSenderEmail;
  private        java.sql.Timestamp  dSentDate;
  private        String     sDeleted;
  private        String     sRead;
  private        String     sRecent;
  private        String     sAnswered;
  private        String     sContentType;
  private        int        iSize;

  private static Object[]   mailHeader = new Object[11];

  private        String     sqlType;

  /*
   * If you're intending to change the top level object names
   * (MAIL_T, MAIL_CLIENT) to custom names, make sure to change
   * the names also here. This is important for proper functioning
   */

  private static String TYPENAME_MAIL_T = "MAIL_T";
  private static String TYPENAME_MAIL_CT = "MAIL_CT";
  private static String TYPENAME_MAIL_HEADER_T = "MAIL_HEADER_T";
  private static String TYPENAME_MAIL_HEADER_CT = "MAIL_HEADER_CT";
  private static String TYPENAME_MAIL_PART_T = "MAIL_PART_T";
  private static String TYPENAME_MAIL_PART_CT = "MAIL_PART_CT";

  private static String TYPENAME_MAIL_ARRAY_CT = "MAIL_ARRAY_CT";

  private static String TYPENAME_MAIL_RCPT_T = "MAIL_ADDR_T";
  private static String TYPENAME_MAIL_RCPT_CT = "MAIL_ADDR_CT";

  private static Connection con = null;
  private static ArrayDescriptor maDescr = null;
  private static ArrayDescriptor mhaDescr = null;
  private static ArrayDescriptor mpaDescr = null;
  private static ArrayDescriptor faDescr = null;
  private static ArrayDescriptor rcptaDescr = null;

  private static StructDescriptor mpsDescr = null;
  private static StructDescriptor mhsDescr = null;
  private static StructDescriptor msDescr = null;
  private static StructDescriptor rcptDescr = null;

  static {
    // fix MapCapCommand handlers for 11.2.0.4
    // thanks to Christian Hasslbauer
    MailcapCommandMap mc = (MailcapCommandMap) CommandMap.getDefaultCommandMap();

    if (mc.getAllCommands("multipart/*").length == 0) {
      mc.addMailcap("multipart/*;; x-java-content-handler=com.sun.mail.handlers.multipart_mixed");
    }
    if (mc.getAllCommands("text/html").length == 0) {
      mc.addMailcap("text/html;; x-java-content-handler=com.sun.mail.handlers.text_html");
    }
    if (mc.getAllCommands("text/xml").length == 0) {
      mc.addMailcap("text/xml;; x-java-content-handler=com.sun.mail.handlers.text_xml");
    }
    if (mc.getAllCommands("text/plain").length == 0) {
      mc.addMailcap("text/plain;; x-java-content-handler=com.sun.mail.handlers.text_plain");
    }
    if (mc.getAllCommands("message/rfc822").length == 0) {
      mc.addMailcap("message/rfc822;; x-java-content-handler=com.sun.mail.handlers.message_rfc822");
    }
    CommandMap.setDefaultCommandMap(mc);

    try {
      con = DriverManager.getConnection("jdbc:default:connection:");
      maDescr = ArrayDescriptor.createDescriptor(getObjectTypeOwner(con) + "." + TYPENAME_MAIL_CT, con);
      msDescr = StructDescriptor.createDescriptor(getObjectTypeOwner(con)+"."+TYPENAME_MAIL_T, con);

      mhaDescr = ArrayDescriptor.createDescriptor(getObjectTypeOwner(con) + "." + TYPENAME_MAIL_HEADER_CT, con);
      mhsDescr = StructDescriptor.createDescriptor(getObjectTypeOwner(con)+"."+TYPENAME_MAIL_HEADER_T, con);

      mpaDescr = ArrayDescriptor.createDescriptor(getObjectTypeOwner(con) + "." + TYPENAME_MAIL_PART_CT, con);
      mpsDescr = StructDescriptor.createDescriptor(getObjectTypeOwner(con)+"."+TYPENAME_MAIL_PART_T, con);

      faDescr = ArrayDescriptor.createDescriptor(getObjectTypeOwner(con) + "." + TYPENAME_MAIL_ARRAY_CT, con);

      rcptaDescr = ArrayDescriptor.createDescriptor(getObjectTypeOwner(con) + "." + TYPENAME_MAIL_RCPT_CT, con);
      rcptDescr = StructDescriptor.createDescriptor(getObjectTypeOwner(con)+"."+TYPENAME_MAIL_RCPT_T, con);

           
    } catch (Exception e) {
      e.printStackTrace(System.out);
    }
  }

  public static void setMessageFetchLimit(int pNewLimit) {
    iMessageFetchLimit = pNewLimit;
  }

  public static int getMessageFetchLimit() {
    return iMessageFetchLimit;
  }

  public static String decodeChar(String s) throws Exception {
  		return MimeUtility.decodeHeader(s);
  }


  // Bugfix by Christian Hasslbauer, mb Support - thanks!

  private static int findRfc2047Ending(String s, int pStartIndex) {
      // First divider "?": after charset
      int iResult = s.indexOf("?", pStartIndex + 2);
      if (iResult == -1 ) {
          return iResult;
      }
      // Second divider "?": after encoding
      iResult = s.indexOf("?", iResult + 1);
      if (iResult == -1 ) {
          return iResult;
      }
      // Ending "?="
      iResult = s.indexOf("?=", iResult + 1);
      return iResult;
  }


  public static String decode(String s) throws Exception {
    int iStartPos = 0;
    int iEndPos = 0;
    String sNewString = s;
    if (s != null) {
     iStartPos = s.indexOf("=?");
     if (iStartPos != -1) {
       iEndPos = findRfc2047Ending(s, iStartPos);
 //     Bugfix by Christian Hasslbauer, mb Support
 //     iEndPos = s.indexOf("?=", iStartPos);
      if (iEndPos != -1) {
        sNewString = s.substring(0,iStartPos) + decodeChar(s.substring(iStartPos, iEndPos + 2)) + s.substring(iEndPos + 2);
        sNewString = decode(sNewString);
      }
     }
    }
    return sNewString;
  }

  private static int getCompCode(String pComparison) throws Exception {
    if (pComparison.equals("=") || pComparison.equals("==")) {
      return DateTerm.EQ;
    }
    if (pComparison.equals("!=")) {
      return DateTerm.NE;
    }
    if (pComparison.equals("<=") || pComparison.equals("=<")) {
      return DateTerm.LE;
    }
    if (pComparison.equals(">=") || pComparison.equals("=>")) {
      return DateTerm.GE;
    }
    if (pComparison.equals("<")) {
      return DateTerm.LT;
    }
    if (pComparison.equals(">")) {
      return DateTerm.GT;
    }
    throw new Exception("Invalid Comparison Operator: Allowed is =, !=, <=, >=, <, >");
  }

  public static void clearFilters() throws Exception {
    oMessageFilters.setSize(0);
    iMessageFilterCombination = 0;
  }

  public static void addFromFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new FromStringTerm(pFilter)));
    } else {
      oMessageFilters.add(new FromStringTerm(pFilter));
    }
  }

  public static void addHeaderFilter(String pHeaderName, String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new HeaderTerm(pHeaderName, pFilter)));
    } else {
      oMessageFilters.add(new HeaderTerm(pHeaderName, pFilter));
    }
  }

  public static void addBodyFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new BodyTerm(pFilter)));
    } else {
      oMessageFilters.add(new BodyTerm(pFilter));
    }
  }

  public static void addTOFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new RecipientStringTerm(Message.RecipientType.TO, pFilter)));
    } else {
      oMessageFilters.add(new RecipientStringTerm(Message.RecipientType.TO, pFilter));
    }
  }  

  public static void addCCFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new RecipientStringTerm(Message.RecipientType.CC, pFilter)));
    } else {
      oMessageFilters.add(new RecipientStringTerm(Message.RecipientType.CC, pFilter));
    }
  }  

  public static void addBCCFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new RecipientStringTerm(Message.RecipientType.BCC, pFilter)));
    } else {
      oMessageFilters.add(new RecipientStringTerm(Message.RecipientType.BCC, pFilter));
    }
  }  


  public static void addSentDateFilter(java.sql.Timestamp pFilter, String pOp, int pNot) throws Exception {
    if (pNot == 1) {
     oMessageFilters.add(new NotTerm( new SentDateTerm(getCompCode(pOp), (java.util.Date)(pFilter))));
    } else {
     oMessageFilters.add( new SentDateTerm(getCompCode(pOp), (java.util.Date)(pFilter)));
    }
  }

  public static void addMsgSizeFilter(int pFilter, String pOp, int pNot) throws Exception {
    if (pNot == 1) {
     oMessageFilters.add(new NotTerm( new SizeTerm(getCompCode(pOp), pFilter)));
    } else {
     oMessageFilters.add(new SizeTerm(getCompCode(pOp), pFilter));
    }
  }

  public static void addReceivedDateFilter(java.sql.Timestamp pFilter, String pOp, int pNot) throws Exception {
    if (pNot == 1) {
      oMessageFilters.add(new NotTerm(new ReceivedDateTerm(getCompCode(pOp), (java.util.Date)(pFilter))));
    } else {
      oMessageFilters.add(new ReceivedDateTerm(getCompCode(pOp), (java.util.Date)(pFilter)));
    }
  }

  public static void addSubjectFilter(String pFilter, int pNot) throws Exception {
    if (pNot == 1) {
     oMessageFilters.add(new NotTerm(new SubjectTerm(pFilter)));
    } else {
      oMessageFilters.add(new SubjectTerm(pFilter));
    }
  }

  public static void addDeletedFilter(int pFlagSet) throws Exception {
     oMessageFilters.add(new FlagTerm(new Flags(Flags.Flag.DELETED), (pFlagSet==1?true:false)));
  }

  public static void addSeenFilter(int pFlagSet) throws Exception {
     oMessageFilters.add(new FlagTerm(new Flags(Flags.Flag.SEEN), (pFlagSet==1?true:false)));
  }

  public static void setFilterCombination(int pCombination) throws Exception {
    iMessageFilterCombination = pCombination;
  }

  public static String getObjectTypeOwner(Connection con) throws Exception {
    String sFileTypeOwner = null;
    CallableStatement stmt = con.prepareCall("begin dbms_utility.name_resolve(?,?,?,?,?,?,?,?); end;");
    stmt.setString(1, TYPENAME_MAIL_T);
    stmt.setInt(2, 7);
    stmt.registerOutParameter(3, java.sql.Types.VARCHAR);
    stmt.registerOutParameter(4, java.sql.Types.VARCHAR);
    stmt.registerOutParameter(5, java.sql.Types.VARCHAR);
    stmt.registerOutParameter(6, java.sql.Types.VARCHAR);
    stmt.registerOutParameter(7, oracle.jdbc.OracleTypes.NUMBER);
    stmt.registerOutParameter(8, oracle.jdbc.OracleTypes.NUMBER);
    stmt.execute();
    sFileTypeOwner = stmt.getString(3);
    stmt.close();
    return sFileTypeOwner;
  }

  private static void convertMessageToObject(Message oMsg) throws Exception {
    Address[] oMailSenders = null;
    Address   oMailSender = null;
    String sPersonal = null;
    String sContentType = null;
    mailHeader[0] = new BigDecimal(oMsg.getMessageNumber());
    try {
      if (oMsg.getSubject() == null) {
        mailHeader[1] = new String("");
      } else {
        mailHeader[1] = new String(oMsg.getSubject());
      }
    } catch (Throwable e) {
       mailHeader[1] = new String("");
    }
    try {
      oMailSenders = oMsg.getFrom();
      if (oMailSenders != null) {
       if (oMailSenders[0] != null) {
        oMailSender = oMailSenders[0];
       }
      }
    // 1.1.4: Do not throw an exception for invalid message adresses
    } catch (Exception e) {
      oMailSender = null;
    }

    if (oMailSender != null) {
     if (oMailSender instanceof InternetAddress) {
      sPersonal = ((InternetAddress)oMailSender).getPersonal();
      if (sPersonal == null) {
       mailHeader[2] = new String("");
      } else {
       mailHeader[2] = new String(sPersonal);
      }
     } else {
      mailHeader[2] = oMailSender.toString();
     }
    } else {
     mailHeader[2] = new String("");
    }
      
    try {
      mailHeader[3] = ((InternetAddress)oMailSender).getAddress();
    } catch (NullPointerException e) {
      mailHeader[3] = new String("");
    } catch (ClassCastException e) {
      mailHeader[3] = new String(oMailSender.toString());
    // 1.1.4: Do not throw an exception for invalid message adresses
    } catch (Exception e) {
      mailHeader[3] = new String("");
    }

    try {
      mailHeader[4] = new java.sql.Timestamp(oMsg.getSentDate().getTime());
    } catch (NullPointerException e) {
      mailHeader[4] = null;
    }
    mailHeader[5] = (oMsg.isSet(Flags.Flag.DELETED)?"Y":"N");
    mailHeader[6] = (oMsg.isSet(Flags.Flag.SEEN)?"Y":"N");
    mailHeader[7] = (oMsg.isSet(Flags.Flag.RECENT)?"Y":"N");
    mailHeader[8] = (oMsg.isSet(Flags.Flag.ANSWERED)?"Y":"N");
    try {
      sContentType = oMsg.getContentType();
      if (sContentType != null) {
        if (sContentType.indexOf(';') != -1) {
          mailHeader[9] = sContentType.substring(0, sContentType.indexOf(';'));
        } else {
          mailHeader[9] = sContentType;
        }
      } else {
        mailHeader[9] = null;
      }
    } catch (Exception e) {
      mailHeader[9] = null;
    }
    mailHeader[10] = new BigDecimal(oMsg.getSize());
  }

  private static STRUCT convertObjectToStruct()
  throws Exception {
    return new STRUCT(msDescr, con, mailHeader);
  }

  private Folder getCurrentFolder() {
    return MailHandlerImpl.oCurrentFolder;
  }

  public static String getServiceURL() throws Exception {
    if (bIsConnected) {
      return oMailStore.getURLName().toString();
    } else {
      return null;
    }
  }

  public static void connectToServerSSL(String sHost, int iPort, String sProtocol, String sUser, String sPass)
  throws Exception {
    if (bIsConnected) {
      throw new Exception("Already connected to a mailserver - disconnect first");
    }
    Properties props = new Properties();
    props.setProperty("mail.store.protocol", sProtocol);
    props.setProperty("mail."+sProtocol.toLowerCase()+".socketFactory.class", "javax.net.ssl.SSLSocketFactory");
	 		props.setProperty("mail."+sProtocol.toLowerCase()+".socketFactory.fallback", "false");
    props.setProperty("mail.mime.address.strict", "false"); 

    props.setProperty("mail."+sProtocol.toLowerCase()+".host", sHost);
    props.setProperty("mail."+sProtocol.toLowerCase()+".user", sUser);
    props.setProperty("mail."+sProtocol.toLowerCase()+".password", sPass);
    props.setProperty("mail."+sProtocol.toLowerCase()+".port", Integer.toString(iPort));

    oMailSession = Session.getInstance(props);
    oMailStore   = oMailSession.getStore();
    oMailStore.connect(sHost, iPort, sUser, sPass);
    bIsConnected = true;
  }

  public static void connectToServer(String sHost, int iPort, String sProtocol, String sUser, String sPass)
  throws Exception {
    if (bIsConnected) {
      throw new Exception("Already connected to a mailserver - disconnect first");
    }
    Properties props = new Properties();
    props.setProperty("mail.store.protocol", sProtocol);
    props.setProperty("mail.mime.address.strict", "false"); 

    oMailSession = Session.getInstance(props);
    oMailStore   = oMailSession.getStore();
    oMailStore.connect(sHost, iPort, sUser, sPass);
    bIsConnected = true;
  }

  public static void disconnectFromServer() throws Exception {
    clearFilters();
    if (bIsConnected) {
      oMailStore.close();
      oMailStore = null;
      oMailSession = null;
      oCurrentFolder = null;
      oMessageFilters = new Vector();
      iMessageFilterCombination = 0;
      iMessageFetchLimit = -1;
      bIsConnected = false;
    } else {
    }
  }

  public static int isConnected() {
    if (bIsConnected) {
      return 1;
    } else {
      return 0;
    }
  }

  public static void openInbox() throws Exception {
    openFolder("INBOX");
  }

  public static void createFolder(String sFolderName) throws Exception {
    boolean bSuccess = false;
    bSuccess = (oCurrentFolder.getFolder(sFolderName).create(javax.mail.Folder.HOLDS_FOLDERS + javax.mail.Folder.HOLDS_MESSAGES));

    if (!bSuccess) {
     throw new Exception("Create folder operation failed.");
    }
  }

  /* by Andre Meier */ 
 
  public String getMsgUID() throws Exception {
      String uidl = null;
      Message msg = getCurrentFolder().getMessage(iMessageNumber);

      if (oCurrentFolder instanceof com.sun.mail.pop3.POP3Folder) {
          com.sun.mail.pop3.POP3Folder pop3f =
              (com.sun.mail.pop3.POP3Folder)oCurrentFolder;
          uidl = pop3f.getUID(msg);
          if (uidl == null) {
              uidl = "";
          }

      } else if (oCurrentFolder instanceof com.sun.mail.imap.IMAPFolder) {
          com.sun.mail.imap.IMAPFolder imapf =
              (com.sun.mail.imap.IMAPFolder)oCurrentFolder;
          uidl = String.valueOf(imapf.getUID(msg));
          if (uidl == null) {
              uidl = "";
          }
      } else {
          uidl = "";
      }
      return uidl;
  }

  public  java.sql.Timestamp getMsgReceiveDate() throws Exception {
    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    if (msg.getReceivedDate() != null) {
      return new java.sql.Timestamp(msg.getReceivedDate().getTime());
    } else {
      return null;
    }
  }

  public void moveMessageToFolder(String sTargetFolder) throws Exception {
    Message msg[] = new Message[1];
    msg[0] = getCurrentFolder().getMessage(iMessageNumber);
    Folder  oTargetFolder = oMailStore.getFolder(sTargetFolder);
    getCurrentFolder().copyMessages(msg, oTargetFolder);
    msg[0].setFlag(Flags.Flag.DELETED, true);
  }


  public void copyMessageToFolder(String sTargetFolder) throws Exception {
    Message msg[] = new Message[1];
    msg[0] = getCurrentFolder().getMessage(iMessageNumber);
    Folder  oTargetFolder = oMailStore.getFolder(sTargetFolder);
    getCurrentFolder().copyMessages(msg, oTargetFolder);
  }

  public static void renameFolder(String sFolderName, String sFolderNewName) throws Exception {
    boolean bSuccess = false;
    bSuccess = (oCurrentFolder.getFolder(sFolderName).renameTo(oCurrentFolder.getFolder(sFolderNewName)));
    if (!bSuccess) {
     throw new Exception("Folder rename operation failed.");
    }
  }

  public static void deleteFolder(String sFolderName) throws Exception {
    boolean bSuccess = false;
    bSuccess = (oCurrentFolder.getFolder(sFolderName).delete(true));

    if (!bSuccess) {
     throw new Exception("Delete folder operation failed.");
    }
  }

  public static String getFolderFullName() throws Exception {
    return oCurrentFolder.getFullName();
  }

  public static String getFolderName() throws Exception {
    return oCurrentFolder.getName();
  }

  public static void openFolder(String sFolderName) throws Exception {
    Folder oNewFolder = oMailStore.getFolder(sFolderName);
    if ((oNewFolder.getType()&Folder.HOLDS_MESSAGES) == Folder.HOLDS_MESSAGES) {
      oNewFolder.open(Folder.READ_WRITE);
    }
    if (oCurrentFolder != null) {
      if (oCurrentFolder.isOpen()) {
        closeFolder();
      }
    }
    oCurrentFolder = oNewFolder;
  }

  public static void openParentFolder() throws Exception {
    if (oCurrentFolder.getParent() != null) {
      openFolder(oCurrentFolder.getParent().getFullName()); 
    }
  }
  
  public static void openChildFolder(String sFolderName) throws Exception {
    openFolder(oCurrentFolder.getFolder(sFolderName).getFullName());
  }

  public static void closeFolder() throws Exception {
    try {
      oCurrentFolder.close(false);
    } catch (IllegalStateException e) {
    } catch (Exception e) { 
      throw (e);
    }
    oCurrentFolder = oMailStore.getDefaultFolder();
  }

  public static void expungeFolderPop3() throws Exception {
    oCurrentFolder.close(true);
  }


  public static void expungeFolder() throws Exception {
    oCurrentFolder.expunge();
  }

  public CLOB getMailSimpleContentClob(boolean bSimpleContentOnly) throws Exception {
    CLOB mailBody = null;

    String sMailContent = getMailSimpleContent(bSimpleContentOnly);
    if (sMailContent == null) {
      mailBody = null;
    } else {
      mailBody = CLOB.createTemporary(con, true, CLOB.DURATION_SESSION);
      Writer  oClobWriter = mailBody.getCharacterOutputStream(0L);
      oClobWriter.write(sMailContent);
      oClobWriter.close();
    }
    return mailBody;
  }

  public CLOB getMailSimpleContentClob() throws Exception {
    return getMailSimpleContentClob(true);
  }

  public CLOB getMailContentClob() throws Exception {
    return getMailSimpleContentClob(false);
  }

  public String getContentType() throws Exception {
    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    return msg.getContentType();
  }

  public int getPartCount() throws Exception {
    return getMailContentPartChildCount("");
  }

  public String getMailSimpleContent(boolean bSimpleContentOnly) throws Exception {
    String sMailContent = null;

    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    Object oContent = msg.getContent();
    if (oContent instanceof java.lang.String) {
      sMailContent = (String)oContent;
    } else {
      if (!bSimpleContentOnly) {
        if (oContent instanceof javax.mail.Multipart) {
          BodyPart bp = ((Multipart)oContent).getBodyPart(0);
          if (bp.getContent() instanceof java.lang.String) {
            sMailContent = (String)bp.getContent();
          }
        }
      }
    }
    return sMailContent;
  }

  public String getMailSimpleContent() throws Exception {
    return getMailSimpleContent(true);
  }

  public String getMailContent() throws Exception {
    return getMailSimpleContent(false);
  }

  private Part traverseToPart(Message startMsg, String sPartIndexes) throws Exception {
    StringTokenizer st       = null;
    Object          oContent = startMsg.getContent();
    Part            msg      = null;
    boolean         go       = true;
    int             iPartIdx = 0;

    if (sPartIndexes != null && !sPartIndexes.equals("")) {
      st = new StringTokenizer(sPartIndexes, ",");
      while (st.hasMoreTokens() && go) {
        iPartIdx = Integer.parseInt(st.nextToken());
        try {
          msg = ((Multipart)oContent).getBodyPart(iPartIdx);
        } catch (ClassCastException e) {
          throw new Exception ("Message seems not to be a multipart message");
        }
        if (msg.getContentType().toLowerCase().startsWith("multipart")) {
          go = true;
          oContent = msg.getContent();
        } else {
          go = false;
        }
      }
    } else {
      msg = startMsg;
    }
    return msg;
  }

  public ARRAY getMessageHeaders() throws Exception {
   return getMessageHeaders("");
  }

  public String getPriority() throws Exception {
    String[] sPrioHeaders = null;
    String   sPrio = null;

    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    sPrioHeaders = msg.getHeader("X-Priority");
    if (sPrioHeaders != null) {
      if (sPrioHeaders.length > 0) {
        sPrio = sPrioHeaders[0];
      }
    }
    return sPrio;
  }


  public static ARRAY getFolders() throws Exception {
    Folder[] oFolders = null;
    Vector vFolderNames = null;

    oFolders = oCurrentFolder.list();
    vFolderNames = new Vector();
    for (int i=0;i<oFolders.length;i++) {
      vFolderNames.add(oFolders[i].getName()) ;
    }
    return new ARRAY(faDescr, con, vFolderNames.toArray());
  }

  public static ARRAY getSharedFolders () throws Exception {
    Folder[] oFolders = null;
    Vector vFolderNames = null;

    oFolders = oMailStore.getSharedNamespaces();
    if (oFolders != null) {
      vFolderNames = new Vector();
      for (int i=0;i<oFolders.length;i++) {
        vFolderNames.add(oFolders[i].getFullName());
      }
      return new ARRAY(faDescr, con, vFolderNames.toArray());
    } else {
      return null;
    }
  }

  private Vector getAddresses(String sType, Address[] a, Vector v) throws Exception {
    Object[] o = new Object[3];
    if (a != null) {
      for (int i=0;i<a.length;i++) {
        o[0] = sType;
        try {
          o[1] = ((InternetAddress)a[i]).getPersonal();
          o[2] = ((InternetAddress)a[i]).getAddress();
        } catch (NullPointerException e) {
          o[1] = "";
          o[2] = "";
        } catch (ClassCastException e) {
          o[1] = "";
          o[2] = new String(a[i].toString());
        }
        v.add(new STRUCT(rcptDescr, con, o));
      } 
    } 
    return v; 
  }

  public ARRAY getMessageRecipients() throws Exception {
    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    Vector v = new Vector();
    v = getAddresses("TO", msg.getRecipients(Message.RecipientType.TO), v);
    v = getAddresses("CC", msg.getRecipients(Message.RecipientType.CC), v);
    v = getAddresses("BCC", msg.getRecipients(Message.RecipientType.BCC), v);
    return new ARRAY(rcptaDescr, con, v.toArray());
  }

  public ARRAY getMessageReplyTo() throws Exception {
    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    Vector v = new Vector();
    v = getAddresses("REPLYTO", msg.getReplyTo(), v);
    return new ARRAY(rcptaDescr, con, v.toArray());
  }

  public ARRAY getMessageHeaders(String sPartIndexes) throws Exception {

    Object[] oHeader = new Object[2];
    Vector vHeaders = new Vector();
    Header oCurrentHeader = null;

    Part msg = traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes);
    if (msg instanceof javax.mail.Part) {
      Enumeration e = msg.getAllHeaders();
      while (e.hasMoreElements()) {
        oCurrentHeader = (Header)e.nextElement();
        oHeader[0] = oCurrentHeader.getName();
        oHeader[1] = oCurrentHeader.getValue();
        vHeaders.add(new STRUCT(mhsDescr, con, oHeader));
      }
    }
    return new ARRAY(mhaDescr, con, vHeaders.toArray());
  }

  public CLOB dumpMessageClob() throws Exception {

    CLOB               mailBody = null;
    InputStreamReader  isContentStream = null;
    Writer             osBlobStream = null;
    char[]             charArray = null;
    int                iCharsRead = 0;

    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    isContentStream = new InputStreamReader(msg.getInputStream());

    mailBody = CLOB.createTemporary(con, true, MailHandlerImpl.TEMPLOB_DURATION);
    osBlobStream = mailBody.getCharacterOutputStream(0L);
    charArray = new char[mailBody.getChunkSize()];

    while ( (iCharsRead = isContentStream.read(charArray)) != -1) {
      osBlobStream.write(charArray, 0, iCharsRead);
    }
    osBlobStream.flush();
    osBlobStream.close();
    isContentStream.close();

    return mailBody;
  }

  public BLOB dumpMessageBlob() throws Exception {

    BLOB         mailBody = null;
    InputStream  isContentStream = null;
    OutputStream osBlobStream = null;
    byte[]       byteArray = null;
    int          iBytesRead = 0;

    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    isContentStream = msg.getInputStream();

    mailBody = BLOB.createTemporary(con, true, MailHandlerImpl.TEMPLOB_DURATION);
    osBlobStream = mailBody.getBinaryOutputStream(0L);
    byteArray = new byte[mailBody.getChunkSize()];

    while ( (iBytesRead = isContentStream.read(byteArray)) != -1) {
      osBlobStream.write(byteArray, 0, iBytesRead);
    }
    osBlobStream.flush();
    osBlobStream.close();
    isContentStream.close();

    return mailBody;
  }

  // New implementation for DUMP_MESSAGE_BLOB by Axel Röber
  public BLOB dumpMessageBlob2() throws Exception {
    BLOB         mailBody = null;
    OutputStream osBlobStream = null;

    Message msg = getCurrentFolder().getMessage(iMessageNumber);

    mailBody = BLOB.createTemporary(con, true, MailHandlerImpl.TEMPLOB_DURATION);
    osBlobStream = mailBody.getBinaryOutputStream(0L);
    msg.writeTo(osBlobStream);
    osBlobStream.flush();
    osBlobStream.close();
    return mailBody;
  }

  // New implementation for DUMP_MESSAGE_CLOB by Axel Röber
  public CLOB dumpMessageClob2() throws Exception {
    CLOB mailBody = null;
    InputStream isContentStream = null;
    Writer osBlobStream = null;
    byte[] buffer = new byte[4096];
    int iCharsRead = 0;
    ByteArrayOutputStream bos = new ByteArrayOutputStream();
    Charset charset = null;
 
    Message msg = getCurrentFolder().getMessage(iMessageNumber);
    isContentStream = msg.getInputStream();
    ContentType ct = new ContentType(msg.getContentType());
    String ctCharset = ct.getParameter("charset");

    if (ctCharset == null || ctCharset.length() == 0) {
      charset = Charset.defaultCharset();
    } else {
      try {
        charset = Charset.forName(javax.mail.internet.MimeUtility.javaCharset(ctCharset));
      } catch (Exception e) {
        charset = Charset.defaultCharset();
      }
    }

    mailBody = CLOB.createTemporary(con, true, MailHandlerImpl.TEMPLOB_DURATION);
    osBlobStream = mailBody.getCharacterOutputStream(0L);
    while ( (iCharsRead = isContentStream.read(buffer)) != -1) {
      bos.write(buffer, 0, iCharsRead);
    }
    osBlobStream.append(new String(bos.toByteArray(), charset.name()));
    osBlobStream.flush();
    osBlobStream.close();
    isContentStream.close();
    return mailBody;
  }

  private void addMessageParts(Vector vMessageParts, Multipart msg, String sIndex) throws Exception {

    Object   oMsgPart[] = new Object[7];
    BodyPart bpMailPart = null;

    for (int i=0;i<msg.getCount();i++) {
      bpMailPart = msg.getBodyPart(i);
      if (sIndex.equals("")) {
        oMsgPart[0] = String.valueOf(i);
        oMsgPart[1] = null;
      } else {
        oMsgPart[0] = sIndex + "," + i;
        oMsgPart[1] = sIndex;
      }

      try {
        oMsgPart[2] = bpMailPart.getFileName();
      } catch (Exception e) {
        oMsgPart[2] = null;
      }
      oMsgPart[3] = bpMailPart.getContentType();
      oMsgPart[4] = bpMailPart.getDisposition();
      oMsgPart[5] = new BigDecimal(bpMailPart.getSize());
      if (bpMailPart.getContentType().toLowerCase().startsWith("multipart")) {
        oMsgPart[6] = new BigDecimal( ((Multipart)bpMailPart.getContent()).getCount());
      } else {
        oMsgPart[6] = new BigDecimal(0);
      }
      vMessageParts.add(new STRUCT(mpsDescr, con, oMsgPart));
      if (bpMailPart.getContentType().toLowerCase().startsWith("multipart")) {
        addMessageParts(vMessageParts, ((Multipart)bpMailPart.getContent()), (String)oMsgPart[0]);
      }
    }
  }

  public ARRAY getMessageInfo() throws Exception {
    Vector                     vMessageParts = new Vector();
    Message                    msg           = getCurrentFolder().getMessage(iMessageNumber);
    Message                    cmsg;
    ByteArrayOutputStream      bos;         
    ByteArrayInputStream       bis;
    String                     lContentType;

    // Workaround for faulty IMAP servers ...
    try {
      lContentType = msg.getContentType();
    } catch (javax.mail.MessagingException e) {
      // convert message object back and forth
      try {
        cmsg         = new MimeMessage((MimeMessage)msg);
        msg          = cmsg;
        lContentType = msg.getContentType();
      } catch (javax.mail.MessagingException e1) {
        bos = new ByteArrayOutputStream();
        msg.writeTo(bos);
        bos.close();
        bis = new ByteArrayInputStream(bos.toByteArray());
        cmsg = new MimeMessage(MailHandlerImpl.oMailSession, bis);
        bis.close();
        msg = cmsg;
      }
    }

    if (msg.getContentType().toLowerCase().startsWith("multipart")) {
      addMessageParts(vMessageParts, (Multipart)msg.getContent(), "");
    }

    return new ARRAY(mpaDescr, con, vMessageParts.toArray());
  }


  public BLOB getMailContentPartBlob(String sPartIndexes) throws Exception {

    Object oContent = null;
    Part   msg = null;

    BLOB         mailBody = null;
    InputStream  isContentStream = null;
    OutputStream osBlobStream = null;
    byte[]       byteArray = null;
    int          iBytesRead = 0;

    msg = traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes);;
    oContent = msg.getContent();

    if (!(oContent instanceof javax.mail.Multipart)) {
      mailBody = BLOB.createTemporary(con, true, MailHandlerImpl.TEMPLOB_DURATION);
      isContentStream = msg.getInputStream();
      osBlobStream = mailBody.getBinaryOutputStream(0L);
      byteArray = new byte[mailBody.getChunkSize()];

      while ( (iBytesRead = isContentStream.read(byteArray)) != -1) {
        osBlobStream.write(byteArray, 0, iBytesRead);
      }
      osBlobStream.flush();
      osBlobStream.close();
      isContentStream.close();
    } else {
      throw new Exception("Selected Message Part is a javax.mail.Multipart object");
    }
    return mailBody;
  }

  public String getMailContentPart(String sPartIndexes) throws Exception  {
    String sPartContent = null;
    int    iPartIndex = 0;

    Object oContent = null;
    String sPartType = null;
    Part msg = null;

    msg = traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes);;
    oContent = msg.getContent();

    if (oContent instanceof java.lang.String) {
      sPartContent = (String)oContent;
    } else {
      throw new Exception ("Selected Message Part is of type "+msg.getContentType());
    }
    return sPartContent;
  }

  public int getMailSize(String sPartIndexes) throws Exception {
    return traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes).getSize();
  }

  public int getMailSize() throws Exception {
    return getMailSize("");
  }

  public String getMailContentPartType(String sPartIndexes) throws Exception {
    return traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes).getContentType();
  }

  public int getMailContentPartChildCount(String sPartIndexes) throws Exception {
    Part msg = traverseToPart(getCurrentFolder().getMessage(iMessageNumber), sPartIndexes);
    if (msg.getContentType().toLowerCase().startsWith("multipart")) {
      return ((Multipart)msg.getContent()).getCount();
    } else {
      return 0;
    }
  }


  public CLOB getMailContentPartClob(String sPartIndexes) throws Exception {
    CLOB mailBody = null;

    String sMailContent = getMailContentPart(sPartIndexes);
    if (sMailContent == null) {
      mailBody = null;
    } else {
      mailBody = CLOB.createTemporary(con, true, CLOB.DURATION_SESSION);
      Writer  oClobWriter = mailBody.getCharacterOutputStream(0L);
      oClobWriter.write(sMailContent);
      oClobWriter.close();
    }
    return mailBody;
  }

  public void markRead() throws Exception {
    getCurrentFolder().getMessage(iMessageNumber).setFlag(Flags.Flag.SEEN, true);
  }

  public void markUnread() throws Exception {
    getCurrentFolder().getMessage(iMessageNumber).setFlag(Flags.Flag.SEEN, false);
  }

  public void markDeleted() throws Exception {
    getCurrentFolder().getMessage(iMessageNumber).setFlag(Flags.Flag.DELETED, true);
  }

  public void markUndeleted() throws Exception {
    getCurrentFolder().getMessage(iMessageNumber).setFlag(Flags.Flag.DELETED, false);
  }

  public static STRUCT getMessage(int iMessageNumber) throws Exception {
    Message msg = oCurrentFolder.getMessage(iMessageNumber);
    convertMessageToObject(msg);
    return convertObjectToStruct();
  }

  private static Message[] gMessageList = null;
  private static int gMessageCursor = 0;

  public static void prepareMessageList() throws Exception {
    FetchProfile fp = new FetchProfile();
    fp.add(FetchProfile.Item.ENVELOPE);
    fp.add(FetchProfile.Item.FLAGS);

    if (oMessageFilters.size()==0) {
      gMessageList = oCurrentFolder.getMessages();
    } else {
      SearchTerm[] st = (SearchTerm[])oMessageFilters.toArray(new SearchTerm[0]);
      if (st.length==1) {
        if (iMessageFilterCombination == 2 || iMessageFilterCombination == 3) {
          gMessageList = oCurrentFolder.search(new NotTerm(st[0]));
        } else {
          gMessageList = oCurrentFolder.search(st[0]);
        }
      } else {
        if (iMessageFilterCombination == 0) {
          gMessageList = oCurrentFolder.search(new AndTerm(st));
        }  
        if (iMessageFilterCombination == 1) {
          gMessageList = oCurrentFolder.search(new OrTerm(st));
        }  
        if (iMessageFilterCombination == 2) {
          gMessageList = oCurrentFolder.search(new NotTerm(new AndTerm(st)));
        }  
        if (iMessageFilterCombination == 3) {
          gMessageList = oCurrentFolder.search(new NotTerm(new OrTerm(st)));
        }  
      }
    }
    oCurrentFolder.fetch(gMessageList, fp);
    gMessageCursor = 0;
  }

  public static STRUCT getNextMessageFromList() throws Exception {
    STRUCT message = null;
    if (gMessageList == null) {
      throw new Exception ("MESSAGE LIST MUST BE POPULATED FIRST: USE prepareMailList()"); 
    }
    if (gMessageCursor < gMessageList.length) {
      convertMessageToObject(gMessageList[gMessageCursor]);
      message = convertObjectToStruct();
      gMessageCursor++;
    } else {
      message = null;
    }
    return message;
  }

  public static int getMessageCount() throws Exception {
    return oCurrentFolder.getMessageCount();
  }

  public static int getNewMessageCount() throws Exception {
    return oCurrentFolder.getNewMessageCount();
  }

  public static int getUnreadMessageCount() throws Exception {
    return oCurrentFolder.getUnreadMessageCount();
  }

  public static ARRAY getAllMailHeaders()
  throws Exception {
    Vector vMails = new Vector();

    FetchProfile fp = new FetchProfile();
    fp.add(FetchProfile.Item.ENVELOPE);
    fp.add(FetchProfile.Item.FLAGS);

    Message[] message = null;
    if (oMessageFilters.size()==0) {
      message = oCurrentFolder.getMessages();
    } else {
      SearchTerm[] st = (SearchTerm[])oMessageFilters.toArray(new SearchTerm[0]);
      if (st.length==1) {
        if (iMessageFilterCombination == 2 || iMessageFilterCombination == 3) {
          message = oCurrentFolder.search(new NotTerm(st[0]));
        } else {
          message = oCurrentFolder.search(st[0]);
        }
      } else {
        if (iMessageFilterCombination == 0) {
          message = oCurrentFolder.search(new AndTerm(st));
        }  
        if (iMessageFilterCombination == 1) {
          message = oCurrentFolder.search(new OrTerm(st));
        }  
        if (iMessageFilterCombination == 2) {
          message = oCurrentFolder.search(new NotTerm(new AndTerm(st)));
        }  
        if (iMessageFilterCombination == 3) {
          message = oCurrentFolder.search(new NotTerm(new OrTerm(st)));
        }  
      }
    }
    oCurrentFolder.fetch(message, fp);

    int iFetchLimit = (iMessageFetchLimit==-1?message.length:Math.min(iMessageFetchLimit, message.length));
    for (int i=0;i<iFetchLimit;i++) {
      convertMessageToObject(message[i]);
      vMails.add(convertObjectToStruct());
    }
    return new ARRAY(maDescr, con, vMails.toArray());
  }

  public void readSQL(SQLInput stream, String typeName) throws SQLException
  {
    sqlType = typeName;
    iMessageNumber = stream.readBigDecimal().intValue();
    sSubject = stream.readString();
    sSender = stream.readString();
    sSenderEmail = stream.readString();
    dSentDate = stream.readTimestamp();
    sDeleted = stream.readString();
    sRead = stream.readString();
    sRecent = stream.readString();
    sAnswered = stream.readString();
  }

  public void writeSQL(SQLOutput stream) throws SQLException
  {
    stream.writeBigDecimal(new BigDecimal(iMessageNumber));
    stream.writeString(sSubject);
    stream.writeString(sSender);
    stream.writeString(sSenderEmail);
    stream.writeTimestamp(dSentDate);
    stream.writeString(sDeleted);
    stream.writeString(sRead);
    stream.writeString(sRecent);
    stream.writeString(sAnswered);
    stream.writeString(sContentType);
    stream.writeInt(iSize);
  }

  public String getSQLTypeName() throws SQLException {
    return sqlType;
  }
}
/
sho err

create or replace type mail_addr_t as object (
  rcpt_type    varchar2(8),
  rcpt_name    varchar2(500),
  rcpt_address varchar2(500)
)
/

create or replace type mail_addr_ct as table of mail_addr_t
/

create or replace type mail_array_ct as table of varchar2(4000)
/

create or replace type mail_part_t as object (
  partindex           varchar2(200),
  parent_index        varchar2(200),
  filename            varchar2(200),
  content_type        varchar2(200),
  content_disposition varchar2(200),
  part_size           number,
  child_count         number
)
/

create or replace type mail_part_ct as table of mail_part_t
/

create or replace type mail_header_t as object(
  name    varchar2(4000),
  value   varchar2(4000)
)
/

create or replace type mail_header_ct as table of mail_header_t
/



create or replace type mail_t authid current_user as object(
  msg_number    number,
  subject       varchar2(4000),
  sender        varchar2(200),
  sender_email  varchar2(200),
  sent_date     date,
  deleted       char(1),
  read          char(1),
  recent        char(1),
  answered      char(1),
  content_type  varchar2(200),
  message_size  number,
  member function get_uid return varchar2
    is language java name 'MailHandlerImpl.getMsgUID() return java.lang.String',
  member function get_receivedate return date
    is language java name 'MailHandlerImpl.getMsgReceiveDate() return java.sql.Timestamp',
  member function get_simple_content_varchar2 return varchar2
    is language java name 'MailHandlerImpl.getMailSimpleContent() return java.lang.String',
  member function get_simple_content_clob return clob
    is language java name 'MailHandlerImpl.getMailSimpleContentClob() return oracle.sql.CLOB',
  member function get_content_varchar2 return varchar2
    is language java name 'MailHandlerImpl.getMailContent() return java.lang.String',
  member function get_content_clob return clob
    is language java name 'MailHandlerImpl.getMailContentClob() return oracle.sql.CLOB',
  member function get_bodypart_content_varchar2(p_partindexes in varchar2) return varchar2
    is language java name 'MailHandlerImpl.getMailContentPart(java.lang.String) return java.lang.String',
  member function get_bodypart_content_clob(p_partindexes in varchar2) return clob
    is language java name 'MailHandlerImpl.getMailContentPartClob(java.lang.String) return oracle.sql.CLOB',
  member function get_bodypart_content_blob(p_partindexes in varchar2) return blob
    is language java name 'MailHandlerImpl.getMailContentPartBlob(java.lang.String) return oracle.sql.BLOB',
  member function get_content_type return varchar2
    is language java name 'MailHandlerImpl.getContentType() return java.lang.String',
  member function get_priority return varchar2
    is language java name 'MailHandlerImpl.getPriority() return java.lang.String',
  member function get_bodypart_content_type(p_partindexes in varchar2) return varchar2
    is language java name 'MailHandlerImpl.getMailContentPartType(java.lang.String) return java.lang.String',
  member function get_multipart_count return number
    is language java name 'MailHandlerImpl.getPartCount() return int',
  member function get_bodypart_multipart_count(p_partindexes in varchar2) return number
    is language java name 'MailHandlerImpl.getMailContentPartChildCount(java.lang.String) return int',
 member function get_structure return mail_part_ct
    is language java name 'MailHandlerImpl.getMessageInfo() return oracle.sql.ARRAY',
  member procedure mark_read
    is language java name 'MailHandlerImpl.markRead()',
  member procedure mark_unread
    is language java name 'MailHandlerImpl.markUnread()',
  member procedure mark_deleted
    is language java name 'MailHandlerImpl.markDeleted()',
  member procedure mark_undeleted
    is language java name 'MailHandlerImpl.markUndeleted()',
  member function get_headers(p_partindexes in varchar2) return mail_header_ct
    is language java name 'MailHandlerImpl.getMessageHeaders(java.lang.String) return oracle.sql.ARRAY',
  member function get_recipients return mail_addr_ct
    is language java name 'MailHandlerImpl.getMessageRecipients() return oracle.sql.ARRAY',
  member function get_replyto return mail_addr_ct
    is language java name 'MailHandlerImpl.getMessageReplyTo() return oracle.sql.ARRAY',
  member function get_headers return mail_header_ct
    is language java name 'MailHandlerImpl.getMessageHeaders() return oracle.sql.ARRAY',
  member function get_size(p_partindexes in varchar2) return number
    is language java name 'MailHandlerImpl.getMailSize(java.lang.String) return int',
  member function get_size return number
    is language java name 'MailHandlerImpl.getMailSize() return int',
  member function dump_clob return clob
    is language java name 'MailHandlerImpl.dumpMessageClob() return oracle.sql.CLOB',
  member function dump_blob return blob
    is language java name 'MailHandlerImpl.dumpMessageBlob() return oracle.sql.BLOB',
  member function dump_clob2 return clob
    is language java name 'MailHandlerImpl.dumpMessageClob2() return oracle.sql.CLOB',
  member function dump_blob2 return blob
    is language java name 'MailHandlerImpl.dumpMessageBlob2() return oracle.sql.BLOB',
  member procedure copy_message (p_target_folder in varchar2)
    is language java name 'MailHandlerImpl.copyMessageToFolder(java.lang.String)',
  member procedure move_message (p_target_folder in varchar2)
    is language java name 'MailHandlerImpl.moveMessageToFolder(java.lang.String)'
)
/
sho err


create or replace type mail_ct as table of mail_t
/

create or replace package mail_client authid current_user as
  PROTOCOL_IMAP constant varchar2(4) := 'imap';
  PROTOCOL_POP3 constant varchar2(4) := 'pop3';


  procedure connect_server (
    p_hostname   in varchar2,
    p_port       in number,
    p_protocol   in varchar2,
    p_userid     in varchar2,
    p_passwd     in varchar2,
    p_ssl        in boolean default false
  );

  function is_connected return number;
  function get_service_url return varchar2;
  function get_shared_namespaces return mail_array_ct;
  function get_folders return mail_array_ct;
  procedure open_inbox;
  procedure open_folder(p_folder in varchar2);
  procedure close_folder;
  procedure expunge_folder;

  procedure disconnect_server;

  function get_mail_headers return mail_ct;
  function get_mail_headers_p return mail_ct pipelined; 

  function get_message(p_message_number in number) return mail_t;
  function rfc_decode(p_text in varchar2) return varchar2;
  procedure create_folder(p_foldername in varchar2) ;
  procedure delete_folder(p_foldername in varchar2) ;
  procedure rename_folder(p_foldername in varchar2, p_new_foldername in varchar2);
  procedure open_parent_folder;
  procedure open_child_folder(p_foldername in varchar2);
  function get_folder_fullname return varchar2;
  function get_folder_name return varchar2;
  function get_message_count return number;
  function get_new_message_count return number;
  function get_unread_message_count return number;
  procedure set_fetch_limit(p_limit in number);
  function get_fetch_limit return number;

end mail_client;
/
sho err

create or replace package body mail_client as
  g_proto varchar2(4);
  g_current_folder varchar2(4000);
 
  function get_service_url return varchar2
  is language java name 'MailHandlerImpl.getServiceURL() return java.lang.String';

  procedure connect_server_intern (
    p_hostname   in varchar2,
    p_port       in number,
    p_protocol   in varchar2,
    p_userid     in varchar2,
    p_passwd     in varchar2
  ) is language java name 'MailHandlerImpl.connectToServer(java.lang.String, int, java.lang.String, java.lang.String, java.lang.String)';

  procedure connect_server_intern_ssl (
    p_hostname   in varchar2,
    p_port       in number,
    p_protocol   in varchar2,
    p_userid     in varchar2,
    p_passwd     in varchar2
  ) is language java name 'MailHandlerImpl.connectToServerSSL(java.lang.String, int, java.lang.String, java.lang.String, java.lang.String)';

  procedure connect_server (
    p_hostname   in varchar2,
    p_port       in number,
    p_protocol   in varchar2,
    p_userid     in varchar2,
    p_passwd     in varchar2,
    p_ssl        in boolean default false
  ) is
  begin
    g_proto := p_protocol;
    if p_ssl then
      connect_server_intern_ssl(p_hostname, p_port,p_protocol, p_userid, p_passwd);
    else
      connect_server_intern(p_hostname, p_port,p_protocol, p_userid, p_passwd);
    end if;
  end;

  function is_connected return number
    is language java name 'MailHandlerImpl.isConnected() return int';

  function get_shared_namespaces return mail_array_ct
    is language java name 'MailHandlerImpl.getSharedFolders() return oracle.sql.ARRAY';

  function get_folders return mail_array_ct
    is language java name 'MailHandlerImpl.getFolders() return oracle.sql.ARRAY';

  procedure disconnect_server
    is language java name 'MailHandlerImpl.disconnectFromServer()';

  procedure open_inbox is
  begin
    open_folder('INBOX');
  end open_inbox;

  procedure do_open_folder(p_folder in varchar2)
    is language java name 'MailHandlerImpl.openFolder(java.lang.String)';

  procedure open_folder(p_folder in varchar2) is
  begin
    do_open_folder(p_folder);
    g_current_folder := get_folder_fullname;
  end open_folder;

  procedure do_open_parent_folder
    is language java name 'MailHandlerImpl.openParentFolder()';

  procedure open_parent_folder is
  begin
    do_open_parent_folder;
    g_current_folder := get_folder_fullname;
  end open_parent_folder;

  procedure do_open_child_folder(p_foldername in varchar2)
    is language java name 'MailHandlerImpl.openChildFolder(java.lang.String)';

  procedure open_child_folder(p_foldername in varchar2) is
  begin
    do_open_child_folder(p_foldername);
    g_current_folder := get_folder_fullname;
  end open_child_folder;

  procedure close_folder
    is language java name 'MailHandlerImpl.closeFolder()';

  procedure expunge_folder_imap
    is language java name 'MailHandlerImpl.expungeFolder()';

  procedure expunge_folder_pop3
    is language java name 'MailHandlerImpl.expungeFolderPop3()';

  PROCEDURE expunge_folder
  -- thanks to Andre Meier for providing this workaround
  IS
  BEGIN
     IF g_proto = protocol_imap
     THEN
        expunge_folder_imap;
     ELSE
        -- For the Sun POP3 implementation Folder.expunge is not supported...
        -- Deshalb eigene Emulation als:
        expunge_folder_pop3;
        -- Erneuetes Íffnen der inbox n÷tig,
        -- weil diese durch expunge_folder_pop3 geschlossen wurde. (Siehe auch dort)
        -- Dadurch wird f³r den Aufrufer ein Verhalten emuliert wie beim imap-Protokoll
        open_folder(g_current_folder);
     END IF;
  END expunge_folder;

  function get_mail_headers return mail_ct
    is language java name 'MailHandlerImpl.getAllMailHeaders() return oracle.sql.ARRAY';

  procedure prepare_mail_headers
    is language java name 'MailHandlerImpl.prepareMessageList()';

  function get_next_message_from_list return mail_t
    is language java name 'MailHandlerImpl.getNextMessageFromList() return oracle.sql.STRUCT';

  function get_mail_headers_p return mail_ct pipelined is
    v_mail     mail_t := null;
    v_fetched  number := 0; 
    v_maxfetch number := get_fetch_limit;
  begin
    prepare_Mail_Headers;
    loop
      v_mail := get_next_message_from_list;
      if v_mail is null or (v_maxfetch != -1 and v_fetched >= v_maxfetch) then 
        exit;
      else 
        pipe row (v_mail);
        v_fetched := v_fetched + 1;
      end if;
    end loop;
    return;
  end get_mail_headers_p;

  function get_message(p_message_number in number) return mail_t
    is language java name 'MailHandlerImpl.getMessage(int) return oracle.sql.STRUCT';

  function rfc_decode(p_text in varchar2) return varchar2
    is language java name 'MailHandlerImpl.decode(java.lang.String) return java.lang.String';

  procedure create_folder(p_foldername in varchar2)
    is language java name 'MailHandlerImpl.createFolder(java.lang.String)';

  procedure delete_folder(p_foldername in varchar2)
    is language java name 'MailHandlerImpl.deleteFolder(java.lang.String)';

  procedure rename_folder(p_foldername in varchar2, p_new_foldername in varchar2)
    is language java name 'MailHandlerImpl.renameFolder(java.lang.String, java.lang.String)';

  function get_folder_fullname return varchar2
    is language java name 'MailHandlerImpl.getFolderFullName() return java.lang.String';

  function get_folder_name return varchar2
    is language java name 'MailHandlerImpl.getFolderName() return java.lang.String';

  function get_message_count return number
    is language java name 'MailHandlerImpl.getMessageCount() return int';

  function get_new_message_count return number
    is language java name 'MailHandlerImpl.getNewMessageCount() return int';

  function get_unread_message_count return number
    is language java name 'MailHandlerImpl.getUnreadMessageCount() return int';

  procedure set_fetch_limit(p_limit in number)
    is language java name 'MailHandlerImpl.setMessageFetchLimit(int)';

  function get_fetch_limit return number
    is language java name 'MailHandlerImpl.getMessageFetchLimit() return int';
end mail_client;
/
sho err

create or replace package mail_filter as
  FILTER_COMB_AND      constant number := 0;
  FILTER_COMB_OR       constant number := 1;
  FILTER_COMB_NOT_AND  constant number := 2;
  FILTER_COMB_NOT_OR   constant number := 3;

  procedure clear_filters; 
  procedure add_from_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_to_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_cc_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_bcc_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_header_filter(p_header in varchar2, p_filter in varchar2, p_match in boolean default true);
  procedure add_body_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_sentdate_filter(p_filter in date, p_comp in varchar2, p_match in boolean default true);
  procedure add_receiveddate_filter(p_filter in date, p_comp in varchar2, p_match boolean default true);
  procedure add_subject_filter(p_filter in varchar2, p_match in boolean default true);
  procedure add_size_filter(p_filter in number, p_comp in varchar2, p_match in boolean default true);
  procedure add_deleted_filter(p_match in boolean default true);
  procedure add_seen_filter(p_match in boolean default true);

  procedure set_filter_combination(p_combination in number default 0);
end mail_filter;
/
sho err

create or replace package body mail_filter as 
  procedure clear_filters 
    is language java name 'MailHandlerImpl.clearFilters()';

  procedure add_from_filter(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addFromFilter(java.lang.String, int)';

  procedure add_from_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_from_filter(p_filter, 0);
    else 
     add_from_filter(p_filter, 1);
    end if;
  end add_from_filter;

  procedure add_to_filter(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addTOFilter(java.lang.String, int)';

  procedure add_to_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_to_filter(p_filter, 0);
    else 
     add_to_filter(p_filter, 1);
    end if;
  end add_to_filter;

  procedure add_cc_filter(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addCCFilter(java.lang.String, int)';

  procedure add_cc_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_cc_filter(p_filter, 0);
    else 
     add_cc_filter(p_filter, 1);
    end if;
  end add_cc_filter;

  procedure add_bcc_filter(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addBCCFilter(java.lang.String, int)';

  procedure add_bcc_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_bcc_filter(p_filter, 0);
    else 
     add_bcc_filter(p_filter, 1);
    end if;
  end add_bcc_filter;

  procedure add_sentdate_filter(p_filter in date, p_comp in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addSentDateFilter(java.sql.Timestamp, java.lang.String, int)';

  procedure add_sentdate_filter(p_filter in date, p_comp in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_sentdate_filter(p_filter, p_comp, 0);
    else 
     add_sentdate_filter(p_filter, p_comp, 1);
    end if;
  end add_sentdate_filter;

  procedure add_receiveddate_filter(p_filter in date, p_comp in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addReceivedDateFilter(java.sql.Timestamp, java.lang.String, int)';

  procedure add_receiveddate_filter(p_filter in date, p_comp in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_receiveddate_filter(p_filter, p_comp, 0);
    else 
     add_receiveddate_filter(p_filter, p_comp, 1);
    end if;
  end add_receiveddate_filter;

  procedure add_size_filter_int(p_filter in number, p_comp in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addMsgSizeFilter(int, java.lang.String, int)';

  procedure add_size_filter(p_filter in number, p_comp in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_size_filter_int(p_filter, p_comp, 0);
    else 
     add_size_filter_int(p_filter, p_comp, 1);
    end if;
  end add_size_filter;

  procedure add_subject_filter(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addSubjectFilter(java.lang.String, int)';

  procedure add_subject_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
     add_subject_filter(p_filter, 0);
    else 
     add_subject_filter(p_filter, 1);
    end if;
  end add_subject_filter;

  procedure add_deleted_filter_int(p_filter in number)
    is language java name 'MailHandlerImpl.addDeletedFilter(int)';

  procedure add_seen_filter_int(p_filter in number)
    is language java name 'MailHandlerImpl.addSeenFilter(int)';

  procedure add_deleted_filter(p_match in boolean default true) is
  begin
    if p_match then add_deleted_filter_int(1); else add_deleted_filter_int(0); end if;
  end add_deleted_filter;
      
  procedure add_seen_filter(p_match in boolean default true) is
  begin
    if p_match then add_seen_filter_int(1); else add_seen_filter_int(0); end if;
  end add_seen_filter;

  procedure add_header_filter_int(p_header in varchar2, p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addHeaderFilter(java.lang.String,java.lang.String, int)';

  procedure add_header_filter(p_header in varchar2, p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
      add_header_filter_int(p_header, p_filter, 0);
    else 
      add_header_filter_int(p_header, p_filter, 1);
    end if;
  end add_header_filter;

  procedure add_body_filter_int(p_filter in varchar2, p_not in number)
    is language java name 'MailHandlerImpl.addBodyFilter(java.lang.String, int)';

  procedure add_body_filter(p_filter in varchar2, p_match in boolean default true) is
  begin
    if p_match then 
      add_body_filter_int(p_filter, 0);
    else 
      add_body_filter_int(p_filter, 1);
    end if;
  end add_body_filter;

  procedure set_filter_combination_int(p_combination in number) 
    is language java name 'MailHandlerImpl.setFilterCombination(int)';

  procedure set_filter_combination(p_combination in number default 0) is
  begin 
    set_filter_combination_int(p_combination);
  end set_filter_combination;
end mail_filter;
/
sho err
