/*++

Copyright (c) 1998-99      Microsoft Corporation

Module Name:

        USBIODEF.H

Abstract:

        Common header file for all USB IOCTLs defined for 
        the core stack. We define them in this single header file 
        so that we can amintain backward comaptibilty with older
        versions of the stack

        

        We divide the IOCTLS supported by the stack as follows:

        kernel IOCTLS:



        user IOCTLS:
        
            IOCTLS Handled by HCD (PORT) FDO
            IOCTLS Handled by HUB FDO
            IOCTLS Handled by USB (DEVICE) PDO

Environment:

    kernel & user mode

Revision History:


--*/

#ifndef   __USBIODEF_H__
#define   __USBIODEF_H__

/*
    kernel mode IOCTL index values

    The following codes are valid only if passed as in 
    the icControlCode parameter for 
    IRP_MJ_INTERNAL_DEVICE_CONTROL
    
*/
#define USB_SUBMIT_URB              0
#define USB_RESET_PORT              1
#define USB_GET_ROOTHUB_PDO         3
#define USB_GET_PORT_STATUS         4
#define USB_ENABLE_PORT             5
#define USB_GET_HUB_COUNT           6
#define USB_CYCLE_PORT              7
#define USB_GET_HUB_NAME            8
#define USB_GET_BUS_INFO            264
#define USB_GET_CONTROLLER_NAME     265
#define USB_GET_BUSGUID_INFO        266
#define USB_GET_PARENT_HUB_INFO     267

/*
    user mode IOCTL index values

    The following codes are valid only if passed as in 
    the icControlCode parameter for 
    IRP_MJ_DEVICE_CONTROL
    hence, they are callable by user mode applications
*/
#define HCD_GET_STATS_1                     255
#define HCD_DIAGNOSTIC_MODE_ON              256
#define HCD_DIAGNOSTIC_MODE_OFF             257
#define HCD_GET_ROOT_HUB_NAME               258
#define HCD_GET_DRIVERKEY_NAME              265
#define HCD_GET_STATS_2                     266
#define HCD_DISABLE_PORT                    268
#define HCD_ENABLE_PORT                     269
#define HCD_USER_REQUEST                    270

#define USB_GET_NODE_INFORMATION                    258
#define USB_GET_NODE_CONNECTION_INFORMATION         259
#define USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION     260
#define USB_GET_NODE_CONNECTION_NAME                261
#define USB_DIAG_IGNORE_HUBS_ON                     262
#define USB_DIAG_IGNORE_HUBS_OFF                    263
#define USB_GET_NODE_CONNECTION_DRIVERKEY_NAME      264

/*
USB specific GUIDs 
*/


/* f18a0e88-c30c-11d0-8815-00a0c906bed8 */
DEFINE_GUID( GUID_CLASS_USBHUB,    0xf18a0e88, 0xc30c, 0x11d0, 0x88, 0x15, 0x00, \
             0xa0, 0xc9, 0x06, 0xbe, 0xd8);

/* A5DCBF10-6530-11D2-901F-00C04FB951ED */
DEFINE_GUID(GUID_CLASS_USB_DEVICE, 0xA5DCBF10L, 0x6530, 0x11D2, 0x90, 0x1F, 0x00, \
             0xC0, 0x4F, 0xB9, 0x51, 0xED);

/* 4E623B20-CB14-11D1-B331-00A0C959BBD2 */
DEFINE_GUID(GUID_USB_WMI_STD_DATA, 0x4E623B20L, 0xCB14, 0x11D1, 0xB3, 0x31, 0x00,\
             0xA0, 0xC9, 0x59, 0xBB, 0xD2);

/* 4E623B20-CB14-11D1-B331-00A0C959BBD2 */
DEFINE_GUID(GUID_USB_WMI_STD_NOTIFICATION, 0x4E623B20L, 0xCB14, 0x11D1, 0xB3, 0x31, 0x00,\
             0xA0, 0xC9, 0x59, 0xBB, 0xD2);             


#define FILE_DEVICE_USB         FILE_DEVICE_UNKNOWN


/* 
   Define the standard USB 'URB' IOCTL here
   
   IOCTL_INTERNAL_USB_SUBMIT_URB

   This IOCTL is used by client drivers to submit URB (USB Request Blocks)

   Parameters.Others.Argument1 = pointer to URB

*/

#define IOCTL_INTERNAL_USB_SUBMIT_URB  CTL_CODE(FILE_DEVICE_USB,  \
                                                USB_SUBMIT_URB,  \
                                                METHOD_NEITHER,  \
                                                FILE_ANY_ACCESS)

/*
    common macro used by IOCTL header files
*/
#define USB_CTL(id)  CTL_CODE(FILE_DEVICE_USB,  \
                                      (id), \
                                      METHOD_BUFFERED,  \
                                      FILE_ANY_ACCESS)

#define USB_KERNEL_CTL(id)  CTL_CODE(FILE_DEVICE_USB,  \
                                      (id), \
                                      METHOD_NEITHER,  \
                                      FILE_ANY_ACCESS)                                      

#endif //__USBIODEF_H__
