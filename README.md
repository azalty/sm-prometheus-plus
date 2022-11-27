# This branch contains the original Prometheus SourceMod plugin.

---

////////////////////////////////////////////////////////////////////////////////////
------------------Prometheus - Sourcemod Donation System *BETA*---------------------
\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\

Made by Nanochip http://steamcommunity.com/id/xNanochip/

INSTALLATION
============

1) Install sourcemod: https://wiki.alliedmods.net/Installing_sourcemod
2) Drag and drop the "addons" folder to your game's root directory.
3) Restart the server.


CONFIGURATION
=============

Once the plugin has been loaded, it will automatically generate "Prometheus.cfg" in your <game>/cfg/sourcemod/ folder. Edit it to your liking.

* sm_prometheus_message
You have the option to use these three arguments. PLAYER_NAME for the donator's steam name, PACKAGE_NAME for the title of the package that they bought, and DONATION_AMOUNT for how much they donated (ex: 9.99). Furthermore, you can add color to the broadcast message (Colors do not work on CS:GO!). Example: {fullred}[Prometheus] {haunted}PLAYER_NAME {honeydew}has donated {haunted}$DONATION_AMOUNT{honeydew} and receives {haunted}PACKAGE_NAME{honeydew}! Thank you!
	- Full list of colors here: https://www.doctormckay.com/morecolors.php

* sm_prometheus_checkinterval
This CVAR specifies the time in seconds in which the plugin checks to see if the donator's ranks have expired. For example, every 600 seconds (10 minutes) it checks all users who have donated to see if their rank has expired.

* sm_prometheus_mode
This CVAR tells the plugin where (and how) to store the donator. There are three options:
Mode 1: Store the player in admins.cfg (Flatfile).
Mode 2: Store the player in the admins MySQL database (MySQL).
Mode 3: Store the player in the Sourcebans admin database (Sourcebans).

FLATFILE:
* You will need to ensure that your "admin-flatfile.smx" plugin exists in addons/sourcemod/plugins/ folder.
* Edit addons/sourcemod/configs/admins.cfg file and make sure that it has "Admins" on the first line, a { on the second line, and a } on the last line.

MYSQL:
* Make sure your MySQL database is set up properly in addons/sourcemod/configs/databases.cfg
* Prometheus uses the "default" connection info, however if you do not want this plugin to use the "default" connection info, add an aditional one and name it "prometheus".
* Update your admin tables! Move addons/sourcemod/plugins/disabled/sql-admin-manager.smx to your plugins folder.
* Restart the server, and run the command "sm_create_adm_tables" from your server console. For MySQL, your database must have CREATE and ALTER permissions.
* Ensure that you are using "admin-sql-threaded.smx" in your addons/sourcemod/plugins/ folder.
* If it is not present, it should be in the addons/sourcemod/plugins/disabled/ folder.

SOURCEBANS:
This mode only works with Sourcebans 2.0 Alpha. https://forums.alliedmods.net/showthread.php?t=219657
Ensure that you are using the sb_admins.smx plugin (which comes with Sourcebans).



SUPPORT & SUGGESTIONS
=====================

Support Page: https://prometheusipn.com/panel/support/

You can leave suggestions for Prometheus - Sourcemod on ScriptFodder https://scriptfodder.com/scripts/view/565
or leave a comment on Nanochip's steam page: http://steamcommunity.com/id/xNanochip/
