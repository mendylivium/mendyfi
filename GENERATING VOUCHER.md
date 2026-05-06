# Generating Voucher Tutorial

This guide shows how to prepare your router, create a voucher profile, generate vouchers, and print them from the panel.

## 1. Set the NAS ID on your router or access point

Before generating vouchers, you need to assign a NAS ID to your router or AP. In this example, MikroTik is used. In Winbox, go to `System` and then `Identity`.

![Open MikroTik Identity](images/1.PNG)

## 2. Open the NAS / Router page in the panel

In the panel, click `NAS / Router`.

![Open NAS / Router in the panel](images/2.PNG)

## 3. Add a new NAS entry

Click `Add NAS`. The NAS ID is important because the RADIUS app checks this first. If the NAS ID does not match the router identity, the request will be rejected. In this example, the NAS ID is `NAS-001`, so the same value is used in MikroTik Identity.

![Add a new NAS entry](images/3.PNG)

## 4. Save the NAS settings

Fill in the other required details, then click `Save` in the panel. In MikroTik, click `OK`.

![Save the NAS settings](images/4.PNG)

## 5. Open voucher profiles

In the panel, go to `Vouchers` and then click `Profiles`.

![Open voucher profiles](images/5.PNG)

## 6. Create a new voucher profile

Click `Add Profile`, then enter the profile details.

![Create a voucher profile](images/6.PNG)

## 7. Save the profile

After entering the profile information, click `Save`.

![Save the voucher profile](images/7.PNG)

## 8. Open available vouchers

Now that the profile is ready, go to `Vouchers` and then select `Available`.

![Open available vouchers](images/8.PNG)

## 9. Generate vouchers

Click `Generate`, fill in the required information, then click `Generate` again.

![Generate vouchers](images/9.PNG)

## 10. Open voucher templates

To print vouchers, you need a voucher template. In the panel, click `Vouchers` and then `Templates`.

![Open voucher templates](images/10.PNG)

## 11. Create a template

Click `Create`. A default template is available, so you only need to give it a name first. If you know HTML and CSS, you can customize the design later.

![Create a voucher template](images/11.PNG)

## 12. Save the template

Click `Create` to save the new template.

![Save the voucher template](images/12.PNG)

## 13. Open the voucher batch for printing

Go back to `Vouchers` and then `Available`. In the `Voucher Batches` table, you will see the batch you generated earlier. Click the `Print` button.

![Open the voucher batch print action](images/13.PNG)

## 14. Select the template and print

Choose the template you created, then click `Print`.

![Select the template and print vouchers](images/14.PNG)