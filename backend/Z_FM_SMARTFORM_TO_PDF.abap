FUNCTION z_fm_smartform_to_pdf.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_CUSTOMER) TYPE  S_CUSTOMER
*"  EXPORTING
*"     VALUE(E_URL) TYPE  STRING
*"     VALUE(E_XSTRING) TYPE  XSTRING
*"     VALUE(E_MIMETYPE) TYPE  W3CONTTYPE
*"     VALUE(E_CUSTOMER) TYPE  S_CUSTOMER
*"     VALUE(ET_LIST) TYPE  ZTT_SFTOPDF
*"----------------------------------------------------------------------

* Data Declaration
  DATA :
    lv_fm_name            TYPE rs38l_fnam,
    ls_output_options     TYPE ssfcompop,
    lv_language           TYPE tdspras,
    ls_control_parameters TYPE ssfctrlop,
    ls_output_data        TYPE ssfcrescl,
    lv_pdf_len            TYPE i,
    lv_pdf_xstring        TYPE xstring,
    lt_lines              TYPE TABLE OF tline,
    lv_devtype            TYPE rspoptype,
    lv_app_type           TYPE string,
    lv_guid               TYPE guid_32,
    lo_cached_response    TYPE REF TO if_http_response,
    ls_customer           TYPE  scustom,
    lt_bookings           TYPE  ty_bookings,
    lt_connections        TYPE  ty_connections,
    lt_tstotf             TYPE tsfotf.

* language
  lv_language = sy-langu.

  TRANSLATE lv_language TO UPPER CASE.
  ls_control_parameters-langu = lv_language.

* set control parameters to get the output text format (OTF) from Smart Forms
  ls_control_parameters-no_dialog = 'X'.
  ls_control_parameters-getotf    = 'X'.
  ls_control_parameters-preview = space. "No preview

* get device type from language
  CALL FUNCTION 'SSF_GET_DEVICE_TYPE'
    EXPORTING
      i_language             = lv_language
*     i_application          = 'SAPDEFAULT'
    IMPORTING
      e_devtype              = lv_devtype
    EXCEPTIONS
      no_language            = 1
      language_not_installed = 2
      no_devtype_found       = 3
      system_error           = 4
      OTHERS                 = 5.

* set device type in output options
  ls_output_options-tdprinter = lv_devtype.
* Set relevant output options
  ls_output_options-tdnewid  = 'X'. "Print parameters,
  ls_output_options-tddelete = space. "Print parameters

  CALL FUNCTION 'SSF_FUNCTION_MODULE_NAME'
    EXPORTING
      formname           = 'SF_EXAMPLE_03'  "Smartform name
    IMPORTING
      fm_name            = lv_fm_name
    EXCEPTIONS
      no_form            = 1
      no_function_module = 2
      OTHERS             = 3.

* data retrieval and supplying it to samrtform fm

  SELECT SINGLE * FROM scustom INTO ls_customer WHERE id = i_customer.
  SELECT * FROM sbook INTO TABLE lt_bookings   WHERE customid = i_customer.
  SELECT * FROM spfli INTO TABLE lt_connections UP TO 10 ROWS.

* call smartform generated fm
  CALL FUNCTION lv_fm_name
    EXPORTING
      control_parameters = ls_control_parameters
      output_options     = ls_output_options
      user_settings      = space
      customer           = ls_customer
      bookings           = lt_bookings
      connections        = lt_connections
    IMPORTING
      job_output_info    = ls_output_data
    EXCEPTIONS
      formatting_error   = 1
      internal_error     = 2
      send_error         = 3
      user_canceled      = 4
      OTHERS             = 5.

  APPEND LINES OF ls_output_data-otfdata[] TO lt_tstotf[].


* convert to otf
  CALL FUNCTION 'CONVERT_OTF'
    EXPORTING
      format                = 'PDF'
    IMPORTING
      bin_filesize          = lv_pdf_len
      bin_file              = lv_pdf_xstring       " binary file
    TABLES
      otf                   = lt_tstotf
      lines                 = lt_lines
    EXCEPTIONS
      err_max_linewidth     = 1
      err_format            = 2
      err_conv_not_possible = 3
      err_bad_otf           = 4
      OTHERS                = 5.
  IF sy-subrc <> 0.
*   error handling
*    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
*            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


  e_xstring = lv_pdf_xstring.

  CREATE OBJECT lo_cached_response
    TYPE
    cl_http_response
    EXPORTING
      add_c_msg = 1.

****set the data and the headers
  lo_cached_response->set_data( lv_pdf_xstring ).
  lv_app_type = '.PDF'.

  lo_cached_response->set_header_field( name  = if_http_header_fields=>content_type
                                     value = lv_app_type ).
****Set the Response Status
  lo_cached_response->set_status( code = 200 reason = 'OK' ).

****Set the Cache Timeout - 60 seconds - we only need this in the cache
****long enough to build the page
  lo_cached_response->server_cache_expire_rel( expires_rel = 60 ).

****Create a unique URL for the object and export URL
  CALL FUNCTION 'GUID_CREATE'
    IMPORTING
      ev_guid_32 = lv_guid.
  CONCATENATE  '/sap/public' '/' lv_guid '.' 'PDF' INTO e_url.
****Cache the URL
  cl_http_server=>server_cache_upload( url      = e_url
                                       response = lo_cached_response ).

  CALL FUNCTION 'SDOK_MIMETYPE_GET'
    EXPORTING
      extension = 'PDF'
    IMPORTING
      mimetype  = e_mimetype.

  E_CUSTOMER = i_customer.

  ET_LIST[] = VALUE #( ( mime_type = e_mimetype customer =  e_customer file_name = 'example.pdf' media_resource = e_xstring
                         url = e_url ) ).

ENDFUNCTION.