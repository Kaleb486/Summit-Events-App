// Copyright (c) 2020, Salesforce.org. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause.
// License can be found found in the LICENSE file in this repository.
// Created by Thaddaeus Dahlberg on 8/09/2018.

@RestResource(UrlMapping='/summiteventsfeed/*')

global with sharing class SummitEventsFeed {

    private static String feedType { get; set; }
    private static SummitEventsShared SEShared = new SummitEventsShared();

    private class eventItem {
        public String ID { get; set; }
        public String title { get; set; }
        public String instanceDesc { get; set; }
        public String description { get; set; }
        public String longDesc { get; set; }
        public Datetime endDate { get; set; }
        public Datetime start { get; set; }
        public String timezone { get; set; }
        public String eventUrl { get; set; }
        public Boolean eventClosed { get; set; }
        public String className { get; set; }
        public String locationTitle { get; set; }
        public String locationType { get; set; }
        public String locationAddress { get; set; }
        public String locationMapLink { get; set; }
        public String locationBuilding { get; set; }
        public String feedButtonText { get; set; }
        public String sponsors { get; set; }
        public Integer capacityTotal { get; set; }
        public Integer capacityRemaining { get; set; }
    }

    @HttpGet
    global static void getSummitEventsFeed() {
        feedType = RestContext.request.params.get('feedType');

        RestResponse res = RestContext.response;
        String callback = RestContext.request.params.get('callback');
        String serializedJSON = '';

        if (String.isBlank(callback)) {
            res.addHeader('Content-Type', 'application/json');
            callback = '';
        } else {
            res.addHeader('Content-Type', 'application/javascript');
        }

        if (feedType == 'audienceDD') {
            serializedJSON = JSON.serialize(getAudienceDD(Summit_Events__c.Audience__c.getDescribe()));
        } else if (feedType == 'sexDD') {
            serializedJSON = JSON.serialize(getAudienceDD(Summit_Events_Registration__c.Registrant_Gender__c.getDescribe()));
        } else if (feedType == 'eventList') {
            serializedJSON = JSON.serialize(getEventList());
            serializedJSON = serializedJSON.replace('"endDate":', '"end":');
        }
        if (!String.isBlank(callback)) {
            serializedJSON = callback + '(' + serializedJSON + ')';
        }
        res.responseBody = Blob.valueOf(serializedJSON);
    }


    private static List<eventItem> getEventList() {

        //Get namespace if packaged
        String namespace = SummitEventsNamespace.getNamespace();
        if (String.isNotBlank(namespace)) {
            namespace = namespace + '__';
        }

        List<eventItem> EventList = new List<eventItem>();
        RestRequest req = RestContext.request;
        String eventQuery = '';
        eventQuery += ' SELECT Id, Event__r.Name, Event__r.Event_Name__c, Event__r.Event_Status__c, Active_Status__c, Instance_Title__c, Instance_Short_Description__c, Event__r.Program_Filter__c, Event__r.Alternate_Registration_URL__c, ';
        eventQuery += ' Event__r.Location_Title__c, Event__r.Location_Type__c, Event__r.Location_Address__c, Event__r.Location_Map_Link__c, Event__r.Building__c, Event__r.Event_description__c, Event__r.Community_Base_URL__c, ';
        eventQuery += ' Building_Override__c, Alternate_Registration_URL_Override__c, Location_Address_Override__c, Location_Map_Link_Override__c, Location_Title_Override__c, Location_Type_Override__c,  ';
        eventQuery += ' Event__r.Event_Short_Listing_Description__c, Event__r.Audience__c, Event__r.Close_Event_Days_Before__c, Event__r.Event_Sponsor__c, ';
        eventQuery += ' Event__r.Feed_Registration_Button_Text__c, Feed_Registration_Button_Text_Override__c, Capacity__c, Current_Available_Capacity__c, Private_Instance__c, Event__r.Private_Event__c, ';
        eventQuery += ' Instance_Start_Date__c, Instance_End_Date__c, Instance_Start_Time__c, Instance_End_Time__c, Instance_Time_Zone__c ';
        eventQuery += ' FROM Summit_Events_Instance__c ';
        eventQuery += ' WHERE ';
        eventQuery += ' Event__R.Event_Status__c = \'Active\' ';
        eventQuery += ' AND Active_Status__c = \'Active\' ';
        eventQuery += ' AND Event__r.Private_Event__c = false ';
        eventQuery += ' AND Private_Instance__c = false ';

        Boolean hideClosed = false;
        if (String.isNotBlank(req.params.get('hideClosed'))) {
            hideClosed = false;
            try {
                hideClosed = Boolean.valueOf(req.params.get('hideClosed'));
            } catch (Exception e) {
            }
        }
        if (hideClosed) {
            eventQuery += ' AND (Current_Available_Capacity__c > 0 OR Capacity__c = null) ';
        }


        // build and sanitize the where statement that have variables

        // get start and end view times convert string to datetime then convert back into string to sanitize
        Datetime viewStart = null;
        Datetime viewEnd = null;
        ///.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
        String formattedViewStart;
        String formattedViewEnd;
        if (String.isNotBlank(req.params.get('viewStart'))) {
            viewStart = Date.valueOf(String.escapeSingleQuotes(req.params.get('viewStart')));
        }
        //if fullcalendar in use start is passed. start being protected variable
        if (String.isNotBlank(req.params.get('start'))) {
            viewStart = Date.valueOf(req.params.get('start'));
        } else {
            viewStart = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addMonths(-1);
        }

        if (String.isNotBlank(req.params.get('viewEnd'))) {
            viewEnd = Date.valueOf(String.escapeSingleQuotes(req.params.get('viewEnd')));
        }
        //if fullcalendar in use end is passed. end being protected variable
        if (String.isNotBlank(req.params.get('end'))) {
            viewEnd = Date.valueOf(req.params.get('end'));
        } else {
            viewEnd = Datetime.newInstance(Date.today(), Time.newInstance(0, 0, 0, 0)).addMonths(1);

        }

        formattedViewStart = viewStart.format('yyyy-MM-dd');
        formattedViewEnd = viewEnd.format('yyyy-MM-dd');
        eventQuery += ' AND Instance_Start_Date__c >= ' + formattedViewStart + ' ';
        eventQuery += ' AND Instance_Start_Date__c <= ' + formattedViewEnd + ' ';

        //get event based on event id
        String eventId = req.params.get('eventId');
        Id evtId = null;
        try {
            evtId = (Id) eventId;
            eventId = String.valueOf(evtId);
        } catch (Exception e) {
            eventId = null;
        }
        if (!String.isBlank(eventId)) {
            eventQuery += ' AND Event__r.id = \'' + eventId + '\' ';
        }

        //get event based on audience (can be comma seperated)
        String audience = req.params.get('audience');
        if (audience != 'all' && !String.isBlank(audience)) {
            List<String> audienceList = new List<String>();
            audienceList = audience.split(',');
            for (String aud : audienceList) {
                audience = '\'' + String.escapeSingleQuotes(aud) + '\',';
            }
            audience = audience.removeEnd(',');
            eventQuery += ' AND Event__r.Audience__c INCLUDES (' + audience + ') ';
        }

        //Sponsor filter (can be comma seperated)
        String sponsor = req.params.get('sponsor');
        if (!String.isBlank(sponsor)) {
            List<String> sponsorList = new List<String>();
            sponsorList = sponsor.split(',');
            for (String spon : sponsorList) {
                sponsor = '\'' + String.escapeSingleQuotes(spon) + '\',';
            }
            sponsor = sponsor.removeEnd(',');
            eventQuery += ' AND Event__r.Event_Sponsor__c INCLUDES (' + sponsor + ') ';
        }

        //get filter with like soql concatinated program,location, school, location address, location type
        String filter = req.params.get('filter');
        if (!String.isBlank(filter)) {
            eventQuery += ' AND  (';
            List<String> filterList = filter.split(',');
            for (String f : filterList) {
                eventQuery += ' Event__r.Program_Filter__c LIKE \'%' + f + '%\' OR ';
                eventQuery += ' Event__r.Location_Title__c LIKE \'%' + f + '%\' OR ';
                eventQuery += ' Event__r.Location_Address__c LIKE \'%' + f + '%\' OR ';
                eventQuery += ' Event__r.Building__c LIKE \'%' + f + '%\' OR ';
            }
            eventQuery = eventQuery.removeEnd('OR ');
            eventQuery += ' ) ';
        }

        String incomingShowLongDesc = req.params.get('longdesc');
        Boolean showLongDescription = false;
        if (incomingShowLongDesc != null) {
            if (incomingShowLongDesc.toLowerCase() == '1' || incomingShowLongDesc.toLowerCase() == 'true') {
                showLongDescription = true;
            }
        }

        eventQuery += ' WITH SECURITY_ENFORCED ';
        List<Summit_Events_Instance__c> EventInstanceList = Database.query(eventQuery);

        Datetime regDateOpenDate = null;
        for (Summit_Events_Instance__c eventInstance : EventInstanceList) {
            regDateOpenDate = Datetime.now().addDays(-1);
            if (eventInstance.Event__r.Close_Event_Days_Before__c != null && eventInstance.Event__r.Close_Event_Days_Before__c != 0) {
                regDateOpenDate = SEShared.adjustForTimeZone(Datetime.now(), eventInstance.Instance_Time_Zone__c);
                regDateOpenDate = regDateOpenDate.addDays((Integer.valueOf(eventInstance.Event__r.Close_Event_Days_Before__c) + 1));
            }
            eventItem evt = new eventItem();
            evt.ID = eventInstance.Id;

            if (eventInstance.Event__r.Event_Name__c != null) {
                evt.title = removeHTMLandEscape(eventInstance.Event__r.Event_Name__c, true);
            } else {
                evt.title = removeHTMLandEscape(eventInstance.Event__r.Name, true);
            }

            if (eventInstance.Instance_Title__c != null) {
                evt.title += ' - ' + removeHTMLandEscape(eventInstance.Instance_Title__c, true);
            }

            if (!String.isBlank(eventInstance.Instance_Short_Description__c)) {
                evt.instanceDesc = removeHTMLandEscape(eventInstance.Instance_Short_Description__c, true);
            } else {
                evt.instanceDesc = '';
            }

            if (!String.isBlank(eventInstance.Feed_Registration_Button_Text_Override__c)) {
                evt.feedButtonText = removeHTMLandEscape(eventInstance.Feed_Registration_Button_Text_Override__c, true);
            } else if (!String.isBlank(eventInstance.Event__r.Feed_Registration_Button_Text__c)) {
                evt.feedButtonText = removeHTMLandEscape(eventInstance.Event__r.Feed_Registration_Button_Text__c, true);
            } else {
                evt.feedButtonText = 'Register';
            }

            if (!String.isBlank(eventInstance.Instance_Time_Zone__c)) {
                evt.timezone = eventInstance.Instance_Time_Zone__c;
            }

            if (!String.isBlank(eventInstance.Location_Type_Override__c)) {
                evt.locationType = removeHTMLandEscape(eventInstance.Location_Type_Override__c, true);
            } else if (!String.isBlank(eventInstance.Event__r.Location_Type__c)) {
                evt.locationType = eventInstance.Event__r.Location_Type__c;
            } else {
                evt.locationType = '';
            }

            if (!String.isBlank(eventInstance.Event__r.Event_Sponsor__c)) {
                evt.sponsors = eventInstance.Event__r.Event_Sponsor__c;
            } else {
                evt.sponsors = '';
            }

            if (!String.isBlank(eventInstance.Event__r.Building__c)) {
                evt.locationBuilding = eventInstance.Event__r.Building__c;
            } else {
                evt.locationBuilding = '';
            }

            if (!String.isBlank(eventInstance.Event__r.Event_Short_Listing_Description__c)) {
                evt.description = removeHTMLandEscape(eventInstance.Event__r.Event_Short_Listing_Description__c, true);
            } else {
                evt.description = '';
            }

            if (showLongDescription) {
                evt.longDesc = eventInstance.Event__r.Event_description__c;
            } else {
                evt.longDesc = '';
            }

            if (Integer.valueOf(eventInstance.Capacity__c) != null) {
                evt.capacityTotal = Integer.valueOf(eventInstance.Capacity__c);
            } else {
                evt.capacityTotal = 0;
            }

            if (Integer.valueOf(eventInstance.Current_Available_Capacity__c) != null) {
                evt.capacityRemaining = Integer.valueOf(eventInstance.Current_Available_Capacity__c);
            } else {
                evt.capacityRemaining = 0;
            }

            if (eventInstance.Instance_Start_Date__c != null) {
                evt.start = SEShared.convertDateToDatetime(eventInstance.Instance_Start_Date__c, eventInstance.Instance_Start_Time__c, '');

            }
            if (eventInstance.Instance_End_Date__c != null) {
                evt.endDate = SEShared.convertDateToDatetime(eventInstance.Instance_End_Date__c, eventInstance.Instance_End_Time__c, '');
            }

            if (!String.isBlank(eventInstance.Event__r.Location_Title__c) || !String.isBlank(eventInstance.Location_Title_Override__c)) {
                if (!String.isBlank(eventInstance.Location_Title_Override__c)) {
                    evt.locationTitle = removeHTMLandEscape(eventInstance.Location_Title_Override__c, true);
                } else {
                    evt.locationTitle = removeHTMLandEscape(eventInstance.Event__r.Location_Title__c, true);
                }
            } else {
                evt.locationTitle = '';
            }

            if (!String.isBlank(eventInstance.Event__r.Location_Address__c) || !String.isBlank(eventInstance.Location_Address_Override__c)) {
                if (!String.isBlank(eventInstance.Location_Address_Override__c)) {
                    evt.locationAddress = removeHTMLandEscape(eventInstance.Location_Address_Override__c, true);
                } else {
                    evt.locationAddress = removeHTMLandEscape(eventInstance.Event__r.Location_Address__c, true);
                }
            } else {
                evt.locationAddress = '';
            }

            if (!String.isBlank(eventInstance.Event__r.Location_Map_Link__c) || !String.isBlank(eventInstance.Location_Map_Link_Override__c)) {
                if (!String.isBlank(eventInstance.Location_Map_Link_Override__c)) {
                    evt.locationMapLink = removeHTMLandEscape(eventInstance.Location_Map_Link_Override__c, false);
                } else {
                    evt.locationMapLink = removeHTMLandEscape(eventInstance.Event__r.Location_Map_Link__c, false);
                }
            } else {
                evt.locationMapLink = '';
            }

            if (evt.start < regDateOpenDate || eventInstance.Current_Available_Capacity__c <= 0) {
                evt.eventClosed = true;
                evt.eventUrl = 'javascript:;';
                evt.className = 'eventClosed';
                if (!hideClosed) {
                    EventList.add(evt);
                }
            } else {
                evt.eventClosed = false;
                if (!String.isBlank(eventInstance.Event__r.Alternate_Registration_URL__c) || !String.isBlank(eventInstance.Alternate_Registration_URL_Override__c)) {
                    if (!String.isBlank(eventInstance.Alternate_Registration_URL_Override__c)) {
                        evt.eventUrl = removeHTMLandEscape(eventInstance.Alternate_Registration_URL_Override__c, false);
                    } else {
                        evt.eventUrl = removeHTMLandEscape(eventInstance.Event__r.Alternate_Registration_URL__c, false);
                    }

                } else {
                    evt.eventUrl = eventInstance.Event__r.Community_Base_URL__c + namespace + 'SummitEventsRegister?instanceID=' + eventInstance.Id;
                }
                evt.className = 'eventOpened';
                EventList.add(evt);
            }
        }
        return EventList;
    }

    public static String removeHTMLandEscape(String incomingString, Boolean escapeHTML) {
        incomingString = incomingString.replaceAll('<[^>]+>', '').trim();
        if (escapeHTML) {
            incomingString = incomingString.escapeHtml4();
        }
        return incomingString;
    }
    private static Map<String, String> getAudienceDD(Schema.DescribeFieldResult fieldResult) {
        Map<String, String> fieldMap = new Map<String, String>();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry f : ple) {
            fieldMap.put(f.getLabel(), f.getValue());
        }
        return fieldMap;
    }

}