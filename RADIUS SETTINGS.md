# Simple RADIUS Setup Tutorial

This guide shows how to copy the RADIUS settings from the panel and apply them in MikroTik using Winbox.

## 1. Open the panel and check the RADIUS settings

After you open the panel and log in, go to the settings page and review the RADIUS details.

![RADIUS settings in the panel](images/rad1.PNG)

## 2. Open RADIUS in Winbox

In Winbox, open the `RADIUS` menu.

![Open RADIUS in Winbox](images/rad2.PNG)

## 3. Create a new RADIUS entry

Click `New` to add a new RADIUS server.

![Create a new RADIUS entry](images/rad3.PNG)

## 4. Copy the panel settings into MikroTik

Copy the RADIUS details from the panel into the MikroTik RADIUS settings.

![Paste the RADIUS settings into MikroTik](images/rad4.PNG)

## 5. Open Hotspot settings

To enable RADIUS for Hotspot, go to `IP` and then select `Hotspot`.

![Open Hotspot settings](images/rad5.PNG)

## 6. Open Server Profiles

Click the dropdown arrow, then select `Server Profiles` from the list.

![Open Server Profiles](images/rad6.PNG)

## 7. Enable RADIUS in the default profile

Open the default profile, go to the `RADIUS` tab, then check `RADIUS` to enable it.

![Enable RADIUS in the hotspot profile](images/rad7.PNG)