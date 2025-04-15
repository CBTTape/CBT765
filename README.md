# CBT765
Converted to GitHub via [cbt2git](https://github.com/wizardofzos/cbt2git)

This is still a work in progress. 
Due to amazing work by Alison Zhang and Jake Choi repos are no longer deleted.

```
//***FILE 765 is from Stephen Odo and contains a home-grown forms   *   FILE 765
//*           based authentication system for the IBM HTTP Server   *   FILE 765
//*           for z/OS.  The following information describes this   *   FILE 765
//*           system:                                               *   FILE 765
//*                                                                 *   FILE 765
//*           Forms-based Authentication for the                    *   FILE 765
//*              IBM HTTP Server for z/OS                           *   FILE 765
//*              ------------------------                           *   FILE 765
//*                                                                 *   FILE 765
//*     This is something I wrote to do forms-based                 *   FILE 765
//*     authentication with the HTTP server for z/OS (the           *   FILE 765
//*     one that comes free with z/OS).                             *   FILE 765
//*                                                                 *   FILE 765
//*     It's not very polished. And it's kinda slow.  It's          *   FILE 765
//*     really just a proof-of-concept thing that never went        *   FILE 765
//*     much further.  But I hope it is useful to somebody.         *   FILE 765
//*                                                                 *   FILE 765
//*     This REXX program and some supporting PL/I programs         *   FILE 765
//*     implement forms-based authentication for the IBM HTTP       *   FILE 765
//*     Server for z/OS.                                            *   FILE 765
//*                                                                 *   FILE 765
//*     We're a poor, State-run, academic institution so we         *   FILE 765
//*     can't afford to buy expensive software like the             *   FILE 765
//*     Websphere Application Server where such things as           *   FILE 765
//*     forms-based authentication are built-in (I don't know       *   FILE 765
//*     if it is or not, but was told that was the case).           *   FILE 765
//*                                                                 *   FILE 765
//*     We have the HTTP server that comes as part of the base      *   FILE 765
//*     z/OS system. But, being that we are an academic             *   FILE 765
//*     institution, our network tends to be open to to just        *   FILE 765
//*     about anybody and our customers need to be able to          *   FILE 765
//*     access our systems from around the world. For us, it's      *   FILE 765
//*     important that we have a secure (i.e. encrypted) login      *   FILE 765
//*     process.                                                    *   FILE 765
//*                                                                 *   FILE 765
//*     Also, many of our customers utilize two-factor              *   FILE 765
//*     authentication tokens such as RSA's SecurID tokens or       *   FILE 765
//*     PassGo Technology's DigiPass tokens. We needed an           *   FILE 765
//*     authentication mechanism that took that into account.       *   FILE 765
//*                                                                 *   FILE 765
//*     This program runs as a GWAPI/REXX pre-exit.                 *   FILE 765
//*                                                                 *   FILE 765
//*     To use this program, edit your HTTP server's                *   FILE 765
//*     configuration file.  On my system, it is                    *   FILE 765
//*     /etc/httpd.conf (I think that's the default).  Assuming     *   FILE 765
//*     that you copied the REXX program to directory /myGWAPI,     *   FILE 765
//*     define the program as a pre-exit:                           *   FILE 765
//*                                                                 *   FILE 765
//*       PreExit /usr/lpp/internet                                 *   FILE 765
//*       /bin/IMWX00.so:IMWX00/myGWAPI/RACFauthR.rx                *   FILE 765
//*                                                                 *   FILE 765
//*     I don't know if it's necessary or not, but we defined       *   FILE 765
//*     protection directives for the applications that will be     *   FILE 765
//*     authenticating -- we were originally using BASIC            *   FILE 765
//*     authentication and never took out the directives.  In       *   FILE 765
//*     case this thing needs it, I figured I'd better let you      *   FILE 765
//*     know what we had:                                           *   FILE 765
//*                                                                 *   FILE 765
//*       Protection ITS_User {                                     *   FILE 765
//*               ServerId        ITS_User                          *   FILE 765
//*               AuthType        Basic                             *   FILE 765
//*               PasswdFile      %%SAF%%                           *   FILE 765
//*               Mask            All                               *   FILE 765
//*       }                                                         *   FILE 765
//*     Protect /MVSDS*         ITS_User %%CLIENT%%                 *   FILE 765
//*     Protect /RACFmaint*     ITS_User %%CLIENT%%                 *   FILE 765
//*                                                                 *   FILE 765
//*     Service /MVSDS*     /usr/lpp/internet/bin                   *   FILE 765
//*     /mvsds.so:mvsdsGet*                                         *   FILE 765
//*                                                                 *   FILE 765
//*     Service /RACFmaint* /usr/lpp/internet/bin                   *   FILE 765
//*     /IMWX00.so:IMWX00/myGWAPI/RACFmaint.rx                      *   FILE 765
//*                                                                 *   FILE 765
//*     The PL/I programs are compiled and linked into a load       *   FILE 765
//*     library that is in the HTTP server's STEPLIB. We're         *   FILE 765
//*     using the IBM Enterprise PL/I for z/OS v3r4 compiler.       *   FILE 765
//*     We also had to do                                           *   FILE 765
//*                                                                 *   FILE 765
//*       RDEFINE PROGRAM **                                        *   FILE 765
//*       ADDMEM('MY.IMWLOAD'//NOPADCHK) UACC(READ)                 *   FILE 765
//*     for the load library.                                       *   FILE 765
//*                                                                 *   FILE 765
//*     I didn't include our stylesheets and images because I       *   FILE 765
//*     don't think anybody would be interested in using them.      *   FILE 765
//*     The stylesheets I use were set up as an inside joke --      *   FILE 765
//*     our web applications still look like "green screen"         *   FILE 765
//*     3270 stuff (see the screenshot.jpg).                        *   FILE 765
//*                                                                 *   FILE 765
//*     I hope this is useful to somebody.                          *   FILE 765
//*                                                                 *   FILE 765
//*     -- Stephen                                                  *   FILE 765
//*                                                                 *   FILE 765
//*     Stephen Y Odo                                               *   FILE 765
//*     Sr Systems Programmer                                       *   FILE 765
//*     University of Hawai'i Information Technology Services       *   FILE 765
//*     2565 McCarthy Mall                                          *   FILE 765
//*     Keller Hall, Room 102A                                      *   FILE 765
//*     Honolulu, HI  96822                                         *   FILE 765
//*     (808)956-2383                                               *   FILE 765
//*     Stephen@Hawaii.Edu                                          *   FILE 765
//*                                                                 *   FILE 765
```
