/* REXX **************************************************************/
/*                                                                   */
/*   RACFauthR.rx                                                    */
/*   -------------------------------------------------------------   */
/*   GWAPI/REXX Pre-Exit                                             */
/*                                                                   */
/*   This GWAPI exit routine is used to implement Form-based         */
/*   Authentication on the IBM HTTP Server for z/OS.                 */
/*                                                                   */
/*   We needed to customize the login process for our web-based      */
/*   applications.  The built-in Basic Authentication function       */
/*   lacks a couple of critical pieces:                              */
/*                                                                   */
/*   1) It is not encrypted.  Basic Authentication Base64-encodes    */
/*      the userid and password but sends that in the clear.         */
/*   2) It does not allow for additional credentials.                */
/*                                                                   */
/*   We're an academic institution so our network tends to be open   */
/*   to just about anybody and our customers need to access our      */
/*   systems from all over the world.  It's kinda important that     */
/*   our login information is encrypted.  This exit forces SSL       */
/*   encryption (i.e. all URLs are "httpS://...").                   */
/*                                                                   */
/*   We also need to use two-factor authentication tokens such as    */
/*   RSA's SecurID or PassGo's DigiPass.  With this exit we're able  */
/*   to customize the content of our login information to support    */
/*   our needs.                                                      */
/*                                                                   */
/*   Our shop has PassGo's NC-Pass product to support the            */
/*   security tokens.                                                */
/*                                                                   */
/*   This program runs as a pre-exit because a pre-exit is called    */
/*   all the time whereas an authentication or authorization exit    */
/*   only gets called if you have the appropriate directives         */
/*   included in your web configuration.                             */
/*                                                                   */
/*   -------------------------------------------------------------   */
/*                                                                   */
/*   Modification History:                                           */
/*   02Jul2006 SYO    Initial version                                */
/*                                                                   */
/*   -------------------------------------------------------------   */
/*                                                                   */
/*   Copyright (c) 2006 Stephen Y. Odo                               */
/*   University of Hawai'i Information Technology Services           */
/*                                                                   */
/*   Many thanks to my colleague Russ Tokuyama for having the        */
/*   patience to answer my questions and explain how things work     */
/*   on the web to me.                                               */
/*                                                                   */
/*********************************************************************/

/*-------------------------------------------------------------------*/
/*   Initialization.                                                 */
/*-------------------------------------------------------------------*/
 debug = 1

 NL = X2C('15')
 stemvar.0 = 0
 stemval.0 = 0
 inarea = LEFT(" ", 4096)

 exposeParse = "stemvar. " || ,
               "stemval. " || ,
               "inarea " || ,
               "tbc asc ebc " || ,
               "debug "
 exposeSendLogin = "origURL " || ,
                   "skel_A " || ,
                   "skel_B " || ,
                   "origURL " || ,
                   "debug "

/*   Page skeleton --------------------------------------------------*/
 skel_A =           '<html>' || NL
 skel_A = skel_A ||  '<head>' || NL
 skel_A = skel_A ||   '<title>UH/ITS RACF Login</title>' || NL
 skel_A = skel_A ||   '<script type="text/javascript">' || NL
 skel_A = skel_A ||   '</script>' || NL
 skel_A = skel_A ||    '<link href="https://TestMVS.ITS.Hawaii.Edu/its/gwapi/stylesheets/FMIS.css" ' || ,
                         'rel="stylesheet" type="text/css">' || NL
 skel_A = skel_A ||   '</link>' || NL
 skel_A = skel_A ||  '</head>' || NL

 skel_A = skel_A ||  '<body>' || NL
 skel_A = skel_A ||   '<div id="header-logo">' || NL
 skel_A = skel_A ||    '<img src="https://TestMVS.ITS.Hawaii.Edu/its/gwapi/images/FMISlogo.png"/>' || NL
 skel_A = skel_A ||   '</div>' || NL
 skel_A = skel_A ||   '<div id="header-text">' || NL
 skel_A = skel_A ||    '<font size="+3">UH/ITS Financial Management Information System</font><br style="clear: none;"/>' || NL
 skel_A = skel_A ||    '<font size="+1">RACF Login</font><br/>' || NL
 skel_A = skel_A ||   '</div>' || NL

 skel_B =            '</body>' || NL
 skel_B = skel_B || '</html>' || NL

/*   Translate tables -----------------------------------------------*/
/*      0 1 2 3 4 5 6 7 8 9 A B C D E F               */
 tbc= "000102030405060708090A0B0C0D0E0F"X ||,  /* 00  */
      "101112131415161718191A1B1C1D1E1F"X ||,  /* 10  */
      "202122232425262728292A2B2C2D2E2F"X ||,  /* 20  */
      "303132333435363738393A3B3C3D3E3F"X ||,  /* 30  */
      "404142434445464748494A4B4C4D4E4F"X ||,  /* 40  */
      "505152535455565758595A5B5C5D5E5F"X ||,  /* 50  */
      "606162636465666768696A6B6C6D6E6F"X ||,  /* 60  */
      "707172737475767778797A7B7C7D7E7F"X ||,  /* 70  */
      "808182838485868788898A8B8C8D8E8F"X ||,  /* 80  */
      "909192939495969798999A9B9C9D9E9F"X ||,  /* 90  */
      "A0A1A2A3A4A5A6A7A8A9AAABACADAEAF"X ||,  /* A0  */
      "B0B1B2B3B4B5B6B7B8B9BABBBCBDBEBF"X ||,  /* B0  */
      "C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF"X ||,  /* C0  */
      "D0D1D2D3D4D5D6D7D8D9DADBDCDDDEDF"X ||,  /* D0  */
      "E0E1E2E3E4E5E6E7E8E9EAEBECEDEEEF"X ||,  /* E0  */
      "F0F1F2F3F4F5F6F7F8F9FAFBFCFDFEFF"X      /* F0  */

/*      0 1 2 3 4 5 6 7 8 9 A B C D E F               */
 asc= "00010203DC09C37FCAB2D50B0C0D0E0F"X ||,  /* 00  */
      "10111213DBDA08C11819C8F21C1D1E1F"X ||,  /* 10  */
      "C4B3C0D9BF0A171BB4C2C5B0B1050607"X ||,  /* 20  */
      "CDBA16BCBBC9CC04B9CBCEDF1415FE1A"X ||,  /* 30  */
      "20FF838485A0C68687A4BD2E3C282B7C"X ||,  /* 40  */
      "268288898AA18C8B8DE121242A293BAA"X ||,  /* 50  */
      "2D2FB68EB7B5C78F80A5DD2C255F3E3F"X ||,  /* 60  */
      "9B90D2D3D4D6D7D8DE603A2340273D22"X ||,  /* 70  */
      "9D616263646566676869AEAFD0ECE7F1"X ||,  /* 80  */
      "F86A6B6C6D6E6F707172A6A791F792CF"X ||,  /* 90  */
      "E67E737475767778797AADA8D1EDE8A9"X ||,  /* A0  */
      "5E9CBEFAB8F5F4ACABF35B5DEEF9EF9E"X ||,  /* B0  */
      "7B414243444546474849F0939495A2E4"X ||,  /* C0  */
      "7D4A4B4C4D4E4F505152FB968197A398"X ||,  /* D0  */
      "5CF6535455565758595AFDE299E3E0E5"X ||,  /* E0  */
      "30313233343536373839FCEA9AEBE99F"X      /* F0  */

/*      0 1 2 3 4 5 6 7 8 9 A B C D E F               */
 ebc= "00010203372D2E2F1605250B0C0D0E0F"X ||,  /* 00  */
      "101112133C3D322618193F271C1D1E1F"X ||,  /* 10  */
      "405A7F7B5B6C507D4D5D5C4E6B604B61"X ||,  /* 20  */
      "F0F1F2F3F4F5F6F7F8F97A5E4C7E6E6F"X ||,  /* 30  */
      "7CC1C2C3C4C5C6C7C8C9D1D2D3D4D5D6"X ||,  /* 40  */
      "D7D8D9E2E3E4E5E6E7E8E9BAE0BBB06D"X ||,  /* 50  */
      "79818283848586878889919293949596"X ||,  /* 60  */
      "979899A2A3A4A5A6A7A8A9C04FD0A107"X ||,  /* 70  */
      "68DC5142434447485253545756586367"X ||,  /* 80  */
      "719C9ECBCCCDDBDDDFECFC70B180BFFF"X ||,  /* 90  */
      "4555CEDE49699A9BABAF5FB8B7AA8A8B"X ||,  /* A0  */
      "2B2C092128656264B4383134334AB224"X ||,  /* B0  */
      "22172906202A46661A35083936303A9F"X ||,  /* C0  */
      "8CAC7273740A757677231514046A783B"X ||,  /* D0  */
      "EE59EBEDCFEFA08EAEFEFBFD8DADBCBE"X ||,  /* E0  */
      "CA8F1BB9B6B5E19D90BDB3DAFAEA3E41"X      /* F0  */

/*-------------------------------------------------------------------*/
/*   Check the URL                                                   */
/*-------------------------------------------------------------------*/
 varnam = "DOCUMENT_URI"
 varval = LEFT(" ",1024," ")
 ADDRESS LINKMVS "IMWXXTR varnam varval"
 url = varval
 origURL = url
 IF debug > 0 THEN SAY "*debug* RACFauthR: url='" || url || "'."

/*   Exit if not one of my applications -----------------------------*/
 SELECT
   WHEN SUBSTR(url,1,6)  = "/AuthN"     THEN DO
       applid = ""
     END /* of "WHEN(/AuthN) THEN DO" */
   WHEN SUBSTR(url,1,10) = "/its/docs/" THEN DO
       applid = "/its/docs"
     END /* of "WHEN(/its/docs) THEN DO" */
   WHEN SUBSTR(url,1,6)  = "/MVSDS"     THEN DO
       applid = "/MVSDS"
     END /* of "WHEN(/MVSDS) THEN DO" */
   WHEN SUBSTR(url,1,10) = "/RACFmaint" THEN DO
       applid = "/RACFmaint"
     END /* of "WHEN(/RACFmaint) THEN DO" */
   OTHERWISE                 EXIT 0  /* HTTP_NOACTION */
 END  /*  of "SELECT"  */

 IF debug > 0 THEN
   SAY "*debug* RACFauthR: entered with url ='" || url || "'"

/*-------------------------------------------------------------------*/
/*   Make sure connection is encrypted.                              */
/*-------------------------------------------------------------------*/

 varnam = "HTTPS"
 varval = LEFT(" ",64," ")
 ADDRESS LINKMVS "IMWXXTR varnam varval"
 IF STRIP(varval,"B") ¬= "ON" THEN DO
     varnam = "CONTENT_TYPE"
     varval = "text/html"
     ADDRESS LINKMVS "IMWXSET varnam varval"
     varnam = "CONTENT_ENCODING"
     varval = "ebcdic"
     ADDRESS LINKMVS "IMWXSET varnam varval"
     msg =        skel_A
     msg = msg || '<fieldset>' || NL
     msg = msg || '<legend>Error</legend>' || NL
     msg = msg || 'This application requires encryption. Please use the HTTPS protocol.' || NL
     msg = msg || '</fieldset>' || NL
     msg = msg || '<form method="post" action="https://TestMVS.ITS.Hawaii.Edu' || origURL || '"><br/>' || NL
     msg = msg ||  '<input type="submit" name="continue" value="continue"/>' || NL
     msg = msg || '</form>' || NL
     msg = msg || skel_B
     ADDRESS LINKMVS "IMWXWRT msg"
     IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_OK -- not encrypted"
     EXIT 200  /* HTTP_OK */
   END  /*  of "IF HTTPS¬=ON THEN DO"  */

/*-------------------------------------------------------------------*/
/*   ApplID=AuthN?                                                   */
/*-------------------------------------------------------------------*/
 IF SUBSTR(url,1,6) = "/AuthN" THEN DO
/*   Extract original URL from URL. ---------------------------------*/
     origURL = SUBSTR(url, 7)
     origURL = STRIP(origURL, "B")

/*   Get input information. -----------------------------------------*/
     varnam = "CONTENT_LENGTH"
     varval = LEFT(" ",1024," ")
     ADDRESS LINKMVS "IMWXXTR varnam varval"
     inarea = LEFT(" ", varval)

     varnam = "CONVERT_REQUEST_BODY"
     varval = "YES"
     ADDRESS LINKMVS "IMWXSET varnam varval"

     ADDRESS LINKMVS "IMWXRD inarea"

     CALL ParseData

     racfid = LEFT(" ", 8)
     racfpwd = LEFT(" ", 8)
     racfnewpwd = LEFT(" ", 8)
     racfnewpwd1 = LEFT(" ", 8)
     racfnewpwd2 = LEFT(" ", 8)
     securid = LEFT(" ", 8)
     DO i = 1 TO stemvar.0
       SELECT
         WHEN TRANSLATE(stemvar.i) = "RACFID" THEN
           racfid = stemval.i
         WHEN TRANSLATE(stemvar.i) = "RACFPWD" THEN
           racfpwd = stemval.i
         WHEN TRANSLATE(stemvar.i) = "RACFNEWPWD1" THEN
           racfnewpwd1 = stemval.i
         WHEN TRANSLATE(stemvar.i) = "RACFNEWPWD2" THEN
           racfnewpwd2 = stemval.i
         WHEN TRANSLATE(stemvar.i) = "SECURID" THEN
           securid = stemval.i
         OTHERWISE DO
           END
       END  /*  of "SELECT"  */
     END  /*  of "DO i=1 TO stemvar.0"  */
     racfid = STRIP(racfid,"B")
     racfpwd = STRIP(racfpwd,"B")
     racfnewpwd = STRIP(racfnewpwd,"B")
     racfnewpwd1 = STRIP(racfnewpwd1,"B")
     racfnewpwd2 = STRIP(racfnewpwd2,"B")
     securid = STRIP(securid,"B")
     racfid = TRANSLATE(racfid)
     racfpwd = TRANSLATE(racfpwd) /* don't do this after z/OS 1.8 */

/*   See if the user needs a security token. ------------------------*/
     rc = NEEDTOK(racfid)

     needAtoken = "N"
     IF SUBSTR(rc, 1, 4) = "OK Y" THEN
       needAtoken = "Y"

/*   If new password specified, make sure user confirmed new pwd. ---*/
     IF racfnewpwd1 ¬= "" THEN DO
         IF racfnewpwd1 ¬= racfnewpwd2 THEN DO
             varnam = "CONTENT_TYPE"
             varval = "text/plain"
             ADDRESS LINKMVS "IMWXSET varnam varval"
             varnam = "CONTENT_ENCODING"
             varval = "ebcdic"
             ADDRESS LINKMVS "IMWXSET varnam varval"

             msg = skel_A
             msg = msg || '<form id="loginForm" method="post" action="https://TestMVS.ITS.Hawaii.Edu/AuthN' || ,
                           origURL || '">' || NL
             msg = msg || '<fieldset>' || NL
             msg = msg ||  '<legend>RACF Login Information</legend>' || NL
             msg = msg ||  '<label for="RACFID">RACF ID:</label>' || NL
             IF racfid ¬= '' THEN
               msg = msg ||  '<input id="RACFID" name="RACFID" value="' || racfid || ,
                             '" type="text" size="10"/><br/>' || NL
             ELSE
               msg = msg ||  '<input id="RACFID" name="RACFID" type="text" size="10"/><br/>' || NL
             msg = msg ||  '<label for="RACFpwd">RACF Password:</label>' || NL
             IF racfpwd ¬= '' THEN
               msg = msg ||  '<input id="RACFpwd" name="RACFpwd" value="' || racfpwd || ,
                             '" type="password" size="10"/><br/>' || NL
             ELSE
               msg = msg ||  '<input id="RACFpwd" name="RACFpwd" type="password" size="10"/><br/>' || NL
             msg = msg ||  '<label for="RACFnewPwd1">new RACF Password:</label>' || NL
             msg = msg ||  '<input id="RACFnewPwd1" name="RACFnewPwd1" type="password" size="10"/>' || NL
             msg = msg ||  '<label for="RACFnewPwd2">Confirm new password:</label>' || NL
             msg = msg ||  '<input id="RACFnewPwd2" name="RACFnewPwd2" type="password" size="10"/><br/>' || NL
             IF needAtoken = "Y" THEN DO
                 msg = msg ||  '<label for="SecurID">number displayed on your Security Token</label>' || NL
                 msg = msg ||  '<input id="SecurID" name="SecurID" type="text" size="10"/>' || NL
               END  /*  of "IF needAtoken=Y THEN DO"  */
             msg = msg || '</fieldset>' || NL
             msg = msg || '<fieldset>' || NL
             msg = msg ||  '<legend>Message(s)</legend>' || NL
             msg = msg ||  'FAIL 0016 NewPassword-1 does not match NewPassword-2 <' || origURL || '><br/>' || NL
             msg = msg ||  'Please make sure that what you entered for "New Password" ' ||
                           'matches exactly with what you entered for "Confirm New Password."' || NL
             msg = msg || '</fieldset>' || NL
             msg = msg || '</form>' || NL
             msg = msg || skel_B

             ADDRESS LINKMVS "IMWXWRT msg"
             IF debug > 0 THEN
               SAY "*debug* RACFauthR: Exit HTTP_OK -- non-matching NewPasswords"
             EXIT 200  /* HTTP_OK */
           END
       END
     racfnewpwd = TRANSLATE(racfnewpwd1) /* don't do this after z/OS 1.8 */

/*   Reset applid ---------------------------------------------------*/
     applid = origURL
     IF debug > 0 THEN SAY "*debug* RACFauthR: origURL is '" || applid || "'"
     i = POS("?", applid)
     IF i ¬= 0 THEN applid = SUBSTR(applid, 1, i-1)
     IF debug > 0 THEN SAY "*debug* RACFauthR: Query check (" || i || ") applid is '" || applid || "'"
     i = POS(":", applid)
     IF i ¬= 0 THEN applid = SUBSTR(applid, 1, i-1)
     IF debug > 0 THEN SAY "*debug* RACFauthR: Function check (" || i || ") applid is '" || applid || "'"
     i = POS("/", SUBSTR(applid,2))
     IF i ¬= 0 THEN applid = SUBSTR(applid, 1, i)
     IF debug > 0 THEN SAY "*debug* RACFauthR: Filename check (" || i+1 || ") applid is '" || applid || "'"
     IF debug > 0 THEN SAY "*debug* RACFauthR: applid reset to '" || applid || "'"

/*   Authenticate against NC-PASS. ----------------------------------*/
     IF debug > 0 THEN SAY "*debug* RACFauthR: Authenticate ID(" || racfid || ,
         ") pwd(" || LEFT("**********",LENGTH(racfpwd)) || ,
         ") newpwd(" || LEFT("**********",LENGTH(racfnewpwd)) || ,
         ") token(" || securid || ,
         ") originalURL(" || origURL || ")"

     rc = RACauth(racfid, racfpwd, racfnewpwd, securid)
     ncpassRC = rc
     IF debug > 0 THEN
       SAY "*debug* RACFauthR: ncpassRC='" || ncpassRC || "'."
     PARSE VAR ncpassRC ncpassStatus ncpassRet ncpassRsn .

     IF ncpassStatus ¬= "OK" THEN DO
         varnam = "CONTENT_TYPE"
         varval = "text/html"
         ADDRESS LINKMVS "IMWXSET varnam varval"
         varnam = "CONTENT_ENCODING"
         varval = "ebcdic"
         ADDRESS LINKMVS "IMWXSET varnam varval"

         SELECT
           WHEN ncpassRsn = "0024" THEN DO       /* Invalid Password */
               err = "0024 Invalid RACF ID/Password combination "
             END /* of "When 0024" */
           WHEN ncpassRsn = "0025" THEN DO       /* Unacceptable Password */
               err = "0025 Unacceptable Password "
            END /* of "When 0025" */
           WHEN ncpassRsn = "0029" THEN DO       /* Invalid UserID */
               err = "0029 Invalid UserID "
             END /* of "When 0029" */
           WHEN ncpassRsn = "0061" THEN DO       /* Password Expired */
               err = "0061 Password Expired "
             END /* of "When 0061" */
           WHEN ncpassRsn = "0782" THEN DO       /* Revoked */
               err = "0782 Access REVOKEd "
             END /* of "When 0782" */
           WHEN ncpassRsn = "4108" THEN DO       /* not in book ??? */
               err = "4108 Attempted to re-use DigiPass Key "
             END /* of "When 4108" */
           WHEN ncpassRsn = "4109" THEN DO       /* Invalid DigiPass Key */
               err = "4109 Invalid DigiPass Key "
             END /* of "When 4109" */
           OTHERWISE DO
               err = RIGHT(ncpassRsn, 4, "0") || " CKSE" || ncpassRSN || ,
                     "(" || ncpassRet || ") "
             END
         END  /*  of "SELECT" */

         msg = skel_A
         msg = msg || '<form id="loginForm" method="post" action="https://TestMVS.ITS.Hawaii.Edu/AuthN' || ,
                       origURL || '">' || NL
         msg = msg || '<fieldset>' || NL
         msg = msg ||  '<legend>RACF Login Information</legend>' || NL
         msg = msg ||  '<label for="RACFID">RACF ID:</label>' || NL
         IF racfid ¬= '' THEN
           msg = msg ||  '<input id="RACFID" name="RACFID" value="' || racfid || ,
                         '" type="text" size="10"/><br/>' || NL
         ELSE
           msg = msg ||  '<input id="RACFID" name="RACFID" type="text" size="10"/><br/>' || NL
         msg = msg ||  '<label for="RACFpwd">RACF Password:</label>' || NL
         IF racfpwd ¬= '' THEN
           msg = msg ||  '<input id="RACFpwd" name="RACFpwd" value="' || racfpwd || ,
                         '" type="password" size="10"/><br/>' || NL
         ELSE
           msg = msg ||  '<input id="RACFpwd" name="RACFpwd" type="password" size="10"/><br/>' || NL
         IF SUBSTR(err, 1, 4) = "0061" THEN DO
             msg = msg ||  '<label for="RACFnewPwd1">new RACF Password:</label>' || NL
             msg = msg ||  '<input id="RACFnewPwd1" name="RACFnewPwd1" type="password" size="10"/>' || NL
             msg = msg ||  '<label for="RACFnewPwd2">Confirm new password:</label>' || NL
             msg = msg ||  '<input id="RACFnewPwd2" name="RACFnewPwd2" type="password" size="10"/><br/>' || NL
           END
         IF needAtoken = "Y" THEN DO
             msg = msg ||  '<label for="SecurID">number displayed on your Security Token</label>' || NL
             msg = msg ||  '<input id="SecurID" name="SecurID" type="text" size="10"/>' || NL
           END  /*  of "IF needAtoken=Y THEN DO"  */
         msg = msg || '</fieldset>' || NL
         msg = msg || '<fieldset>' || NL
         msg = msg ||  '<legend>Message(s)</legend>' || NL
         msg = msg || err || NL
         msg = msg || '</fieldset><br/>' || NL
         msg = msg || '<input id="login" type="submit" name="loginButton" value="Login"/>' || NL
         msg = msg || '</form>' || NL
         msg = msg || skel_B

         varnam = "HTTP_RESPONSE"
         varval = "200"
         ADDRESS LINKMVS "IMWXSET varnam varval"
         ADDRESS LINKMVS "IMWXWRT msg"
         IF debug > 0 THEN DO
             SAY "*debug* RACFauthR: Exit HTTP_OK -- NC-PASS Authentication Failed."
             SAY "*debug* RACFauthR: msg='" || err || "'"
           END
         EXIT 200  /* HTTP_OK */
       END  /*  of "IF retcode¬=0 THEN DO"  */

/*   Create a session cookie. ---------------------------------------*/
     IF racfnewpwd ¬= '' THEN racfpwd = racfnewpwd
     b64RACF = B64enc(Translate(racfid || ":" || racfpwd, asc, tbc))
     cookieSessionID = NewCookie(b64RACF)
     varnam = "HTTP_SET-COOKIE"
     varval = "sessionID=" || cookieSessionID || ,
              ";path=" || applid || ,
              ";version=0.1;"
     ADDRESS LINKMVS "IMWXSET varnam varval"

     IF debug > 0 THEN
       SAY "*debug* RACFauthR: Set-Cookie sessionID=" || cookieSessionID || ,
           ";path=" || applid || ";version=0.1;"

/*   Set authentication parameters ----------------------------------*/
     varnam = "AUTH_TYPE"
     varval = "Basic"
     ADDRESS LINKMVS "IMWXSET varnam varval"

     varnam = "AUTH_STRING"
     varval = b64RACF
     ADDRESS LINKMVS "IMWXSET varnam varval"

     IF debug > 0 THEN
       SAY "*debug* RACFauthR: set up for HTTPD_AUTHENTICATE"

/*   Display login status page --------------------------------------*/
     varnam = "CONTENT_TYPE"
     varval = "text/html"
     ADDRESS LINKMVS "IMWXSET varnam varval"
     varnam = "CONTENT_ENCODING"
     varval = "ebcdic"
     ADDRESS LINKMVS "IMWXSET varnam varval"

     msg = skel_A
     msg = msg || '<form id="loginForm" method="post" action="https://TestMVS.ITS.Hawaii.Edu' || ,
                   origURL || '">' || NL
     msg = msg || '<fieldset>' || NL
     msg = msg || '<fieldset>' || NL
     msg = msg ||  '<legend>Message(s)</legend>' || NL
     msg = msg ||  'Login successful.' || NL
     msg = msg || '</fieldset><br/>' || NL
     msg = msg || '<input type="submit" name="Continue" value="Continue"/>' || NL
     msg = msg || '</form>' || NL
     msg = msg || skel_B
     ADDRESS LINKMVS "IMWXWRT msg"

     IF debug > 0 THEN
       SAY "*debug* RACFauthR: Exit HTTP_OK -- NC-Pass Authentication Successful"
     EXIT 200 /* HTTP_OK */
   END  /*  of "IF '/AuthN' THEN DO"  */

/*-------------------------------------------------------------------*/
/*   If we got here, then we are in one of my applications AND we    */
/*   are in one of the following situations:                         */
/*   1) we authenticated and have a valid cookie                     */
/*   2) we authenticated but our cookie expired                      */
/*   3) we haven't authenticated yet                                 */
/*                                                                   */
/*   So, see if we have a valid Cookie.                              */
/*-------------------------------------------------------------------*/

/*   Retrieve the Cookie. -------------------------------------------*/
 varnam = "HTTP_COOKIE"
 varval = LEFT(" ",1024," ")
 ADDRESS LINKMVS "IMWXXTR varnam varval"
 cookie = STRIP(varval, "B")

 IF debug > 0 THEN
   SAY "*debug* RACFauthR: retrieved cookie '" || cookie || "'"

/*   See if we have a matching cookie file. -------------------------*/
 IF cookie ¬= "" THEN DO
     IF SUBSTR(cookie, 1, 10) = "sessionID=" THEN
       cookie = SUBSTR(cookie, 11)
     cookiefile = cookie || "-cookie.txt"
     cookiepath = "/u/websrv/cookies/" || cookiefile

     existsRC = ""
     existsRC = exists(cookiepath)
     IF debug > 0 THEN SAY "*debug* RACFauthR: exists(" || cookiepath || ") = '" || existsRC || "'"
     IF existsRC ¬= "" THEN DO
/*   Pull information from the Cookie file. -------------------------*/
         rec.0 = 0
         ADDRESS SYSCALL "readfile (cookiepath) rec."

         IF rec.0 = 0 THEN DO
             ADDRESS SH "rm" cookiepath
             Call SendLogin
             IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_FORBIDDEN -- sending login"
             EXIT 403  /* HTTP_FORBIDDEN */
           END

/*   Is the cookie less than 30 minutes old? ------------------------*/
         PARSE VAR rec.1 cookiedt cookietm b64RACF .
         dtstring = DATE("B") TIME("M")
         PARSE VAR dtstring currdt currtm
         cookieage = ((currdt - cookiedt) * (24 * 60)) + (currtm - cookietm)
         IF cookieage <= 30 THEN DO
/*   Update the cookie. ---------------------------------------------*/
             ADDRESS SH "rm" cookiepath
             st.0 = 1
             st.1 = DATE("B") || " " || TIME("M") || " " || b64RACF
             ADDRESS SYSCALL "writefile (cookiepath) 600 st."
/*   Set up for HTTP_AUTHENTICATE. ----------------------------------*/
             varnam = "AUTH_TYPE"
             varval = "Basic"
             ADDRESS LINKMVS "IMWXSET varnam varval"

             varnam = "AUTH_STRING"
             varval = b64RACF
             ADDRESS LINKMVS "IMWXSET varnam varval"

             IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_NOACTION -- do HTTP_AUTHENTICATE"
             EXIT 0  /* HTTP_NOACTION */
           END  /* of "IF cookieage<=30 THEN DO" */
         ELSE DO
             IF debug > 0 THEN SAY "*debug* RACFauthR: Cookie too old. Driving Re-authentication."
             ADDRESS SH "rm" cookiepath
             CALL SendLogin
             IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_FORBIDDEN -- send Login"
             EXIT 403  /* HTTP_FORBIDDEN */
           END  /* of "IF cookieage<=30 THEN...ELSE DO" */
       END  /* of "IF existsRC¬='' THEN DO" */
     ELSE DO
         IF debug > 0 THEN SAY "*debug* RACFauthR: Invalid cookie. Driving Re-Authentication."
         CALL SendLogin
         IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_FORBIDDEN -- send Login"
         EXIT 403  /* HTTP_FORBIDDEN */
       END  /* of "IF existsRC¬='' THEN...ELSE DO" */
   END  /* of "IF cookie¬='' THEN DO" */
 ELSE DO
     IF debug > 0 THEN SAY "*debug* RACFauthR: No cookie. Driving Re-Authentication."
     CALL SendLogin
     IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_FORBIDDEN -- send Login"
     EXIT 403  /* HTTP_FORBIDDEN */
   END  /* of "IF cookie¬='' THEN...ELSE DO" */

 IF debug > 0 THEN SAY "*debug* RACFauthR: Exit HTTP_NOACTION"
 EXIT 0  /* HTTP_NOACTION  */



/*********************************************************************/
/*                                                                   */
/*   ParseData                                                       */
/*   -------------------------------------------------------------   */
/*   Parse the input data.                                           */
/*                                                                   */
/*********************************************************************/

 ParseData: PROCEDURE EXPOSE (exposeParse)

/*-------------------------------------------------------------------*/
/*   Scan the input string and extract variables/values.             */
/*-------------------------------------------------------------------*/

   stemvar.0 = 0
   stembal.0 = 0
   invar = 0
   inval = 0
   concatdat = 0
   n = 0
   i = 1
   pau = 0

   inarea = "&" || inarea
   DO WHILE pau = 0
     byte = SUBSTR(inarea, i, 1)
     SELECT
       WHEN byte = "+" THEN DO
           dat = " "
           concatdat = 1
         END  /*  of "WHEN byte=+ THEN DO"  */
       WHEN byte = "&" THEN DO
           invar = 1
           inval = 0
           n = n + 1
           stemvar.n = ""
         END  /*  of "WHEN byte=& THEN DO"  */
       WHEN byte = "%" THEN DO
           dat = X2C(SUBSTR(inarea,i+1,2))
           dat = TRANSLATE(dat, ebc, tbc)
           i = i + 2
           concatdat = 1
         END  /*  of "WHEN byte=% THEN DO"  */
       WHEN byte = "=" THEN DO
           invar = 0
           inval = 1
           stemval.n = ""
         END  /*  of "WHEN byte== THEN DO"  */
       OTHERWISE DO
           dat = byte
           concatdat = 1
         END  /*  of "OTHERWISE DO"  */
     END  /*  of "SELECT"  */

     IF concatdat = 1 THEN DO
         IF invar = 1 THEN
           stemvar.n = stemvar.n || dat
         ELSE
           stemval.n = stemval.n || dat
         concatdat = 0
         dat = ""
       END  /*  of "IF concatdat=1 THEN DO"  */

     i = i + 1

     IF i > LENGTH(inarea) THEN pau = 1
   END  /*  of "DO WHILE pau=0"  */

   stemvar.0 = n
   stemval.0 = n

 RETURN


/*********************************************************************/
/*                                                                   */
/*   NewCookie                                                       */
/*   -------------------------------------------------------------   */
/*   Create a new session cookie                                     */
/*                                                                   */
/*********************************************************************/

 NewCookie: PROCEDURE

/*-------------------------------------------------------------------*/
/*   Input should be Base64-encoded RACF ID and Password.            */
/*-------------------------------------------------------------------*/
   PARSE ARG b64RACF

/*-------------------------------------------------------------------*/
/*   Generate a random number using ICSF and make sure it's new.     */
/*-------------------------------------------------------------------*/
   loop = 0
   GotOne = 0
   DO WHILE GotOne = 0
     loop = loop + 1
     IF loop > 50 THEN GotOne = 1
     /* Generate a BIG random number --------------------------------*/
     p_ReturnC = D2C(0,4)
     p_ReasonCd = D2C(0,4)
     p_Exit_Data = ""
     p_Exit_Data_Len = D2C(LENGTH(p_Exit_Data),4)
     p_Form = 'RANDOM  '       /** RANDOM, ODD, EVEN **/
     p_Random_Nbr   = COPIES(' ',8)
     ADDRESS LINKPGM 'CSFRNG p_ReturnC p_ReasonCd' ,
                    'p_Exit_Data_Len p_Exit_Data' ,
                    'p_Form' ,
                    'p_Random_Nbr'
     rc = C2D(p_ReturnC,4)
     reas = C2D(p_ReasonCd,4)
     cookie = C2X(p_Random_Nbr)

     p_ReturnC = D2C(0,4)
     p_ReasonCd = D2C(0,4)
     p_Exit_Data = ""
     p_Exit_Data_Len = D2C(LENGTH(p_Exit_Data),4)
     p_Form = 'RANDOM  '       /** RANDOM, ODD, EVEN **/
     p_Random_Nbr   = COPIES(' ',8)
     ADDRESS LINKPGM 'CSFRNG p_ReturnC p_ReasonCd' ,
                    'p_Exit_Data_Len p_Exit_Data' ,
                    'p_Form' ,
                    'p_Random_Nbr'
     rc = C2D(p_ReturnC,4)
     reas = C2D(p_ReasonCd,4)

     cookie = cookie || C2X(p_Random_Nbr)

     cookiefile = cookie || "-cookie.txt"

     /* See if it's in use ------------------------------------------*/
     cookiepath = "/u/websrv/cookies/"cookiefile
     rc = ""
     rc = exists(cookiepath)
     IF rc = "" THEN
       GotOne = 1
   END  /*  of "DO WHILE GotOne=0"  */

/*-------------------------------------------------------------------*/
/*   Create the cookie file.                                         */
/*-------------------------------------------------------------------*/
   st.0 = 1
   st.1 = DATE("B") || " " || ,
         TIME("M") || " " || ,
         b64RACF

   ADDRESS SYSCALL "writefile (cookiepath) 600 st."

   RETURN cookie


/*********************************************************************/
/*                                                                   */
/*   SendLogin                                                       */
/*   -------------------------------------------------------------   */
/*   Send the initial login page                                     */
/*                                                                   */
/*********************************************************************/

 SendLogin:  PROCEDURE EXPOSE (exposeSendLogin)
     NL = X2C('15')

/*   If we have a cookie, purge it. ---------------------------------*/
     varnam = "HTTP_COOKIE"
     varval = LEFT(" ",4096," ")
     ADDRESS LINKMVS "IMWXXTR varnam varval"
     cookie = STRIP(varval, "B")

     IF cookie ¬= "" THEN DO
         IF SUBSTR(cookie, 1, 10) = "sessionID=" THEN
           cookie = SUBSTR(cookie, 11)
         cookiefile = cookie || "-cookie.txt"
         cookiepath = "/u/websrv/cookies/" || cookiefile

         rc = ""
         rc = exists(cookiepath)
         IF rc ¬= "" THEN DO
             ADDRESS SH "rm" cookiepath
           END  /* of "IF rc¬='' THEN DO" */
       END  /* of "IF cookie¬='' THEN DO" */

/*   Send the initial login page. -----------------------------------*/
     msg = skel_A
     msg = msg || '<form id="loginForm" method="post" action="https://TestMVS.ITS.Hawaii.Edu/AuthN' || ,
                  origURL || '">' || NL
     msg = msg || '<fieldset>' || NL
     msg = msg ||  '<legend>RACF Login Information</legend>' || NL
     msg = msg ||  '<label for="RACFID">RACF ID:</label>' || NL
     msg = msg ||  '<input id="RACFID" name="RACFID" type="text" size="10"/><br/>' || NL
     msg = msg ||  '<label for="RACFpwd">RACF Password:</label>' || NL
     msg = msg ||  '<input id="RACFpwd" name="RACFpwd" type="password" size="10"/><br/>' || NL
     msg = msg || '</fieldset>' || NL
     msg = msg || '<fieldset>' || NL
     msg = msg ||  '<legend>Message(s)</legend>' || NL
     msg = msg || '&nbsp;' || NL
     msg = msg || '</fieldset><br/>' || NL
     msg = msg || '<input id="login" type="submit" name="loginButton" value="login"/>'
     msg = msg || '</form>' || NL
     msg = msg || skel_B

     varnam = "CONTENT_TYPE"
     varval = "text/html"
     ADDRESS LINKMVS "IMWXSET varnam varval"
     varnam = "CONTENT_ENCODING"
     varval = "ebcdic"
     ADDRESS LINKMVS "IMWXSET varnam varval"

     ADDRESS LINKMVS "IMWXWRT msg"
   RETURN

