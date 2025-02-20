// Copyright (c) 2020, Salesforce.org. All rights reserved.
// Use of this source code is governed by a BSD 3-Clause.
// License can be found found in the LICENSE file in this repository.
// Created by Thaddaeus Dahlberg on 12/28/2020.

@IsTest
private class SummitEventsSubmit_TEST {

    @IsTest static void testSubmit() {
        SummitEventsTestSharedDataFactory.createContact('TestFirst1', 'TestLast1', 'test1@valleyhill.net', '55418', '(555) 555-5555', '1971-03-22');
        List<Summit_Events_Instance__c> seaTestInstances = SummitEventsTestSharedDataFactory.createTestEvent();
        Summit_Events_Registration__c seaTestRegistration = SummitEventsTestSharedDataFactory.createEventRegistration(seaTestInstances[1], 'TestFirst', 'TestLast', 'test@valleyhill.net', '55418', '1971-03-22', '2012', null);
        User testUser = SummitEventsTestSharedDataFactory.userToRunWith('Standard User', 'Summit_Events_Registrant');
        //Get namespace if packaged
        String namespace = SummitEventsNamespace.getNamespace();
        if (String.isNotBlank(namespace)) {
            namespace = namespace + '__';
        }
        System.runAs(testUser) {
            Test.startTest();
            PageReference pageRef = Page.SummitEventsSubmit;
            pageRef.getParameters().put('adminopen', 'true');
            Test.setCurrentPage(pageRef);

            SummitEventsShared SEShared = new SummitEventsShared();
            SEShared.createEncryptedCookie('Transfer', seaTestInstances[1].Id, seaTestInstances[1].Event__c, seaTestRegistration.Id);

            //ApexPages.currentPage().getParameters().put('instanceID', seaTestInstances.Id);
            SummitEventsSubmitController submitCtrl = new SummitEventsSubmitController();
            System.assertEquals(submitCtrl.checkEventDetails(), null);
            System.assertEquals(submitCtrl.previousPage().getUrl(), '/apex/' + namespace + 'summiteventsregister?adminopen=true');
            System.assertEquals(submitCtrl.submitRegistration().getUrl(), '/apex/' + namespace + 'summiteventsconfirmation?adminopen=true');
            Test.stopTest();
        }
    }

    @IsTest static void testSubmitWithAppointments() {
        SummitEventsTestSharedDataFactory.createContact('TestFirst1', 'TestLast1', 'test1@valleyhill.net', '55418', '(555) 555-5555', '1971-03-22');
        List<Summit_Events_Instance__c> seaTestInstances = SummitEventsTestSharedDataFactory.createTestEvent();
        Summit_Events_Registration__c seaTestRegistration = SummitEventsTestSharedDataFactory.createEventRegistration(seaTestInstances[1], 'TestFirst', 'TestLast', 'test@valleyhill.net', '55418', '1971-03-22', '2012', null);
        List<Summit_Events_Appointment_Type__c> testAppointmentTypes = SummitEventsTestSharedDataFactory.createAppointmentTypes(seaTestInstances[1].Event__c);
        List<Summit_Events_Appointments__c> testAppointments = new List<Summit_Events_Appointments__c>();
        for (Summit_Events_Appointment_Type__c appointmentType : testAppointmentTypes) {
            Summit_Events_Appointments__c appointment = new Summit_Events_Appointments__c();
            appointment.Event_Registration__c = seaTestRegistration.Id;
            testAppointments.add(appointment);
        }
        insert testAppointments;
        User testUser = SummitEventsTestSharedDataFactory.userToRunWith('Standard User', 'Summit_Events_Registrant');
        String namespace = SummitEventsNamespace.getNamespace();
        if (String.isNotBlank(namespace)) {
            namespace = namespace + '__';
        }
        System.runAs(testUser) {
            Test.startTest();
            PageReference pageRef = Page.SummitEventsSubmit;
            Test.setCurrentPage(pageRef);
            SummitEventsShared SEShared = new SummitEventsShared();
            SEShared.createEncryptedCookie('Transfer', seaTestInstances[1].Id, seaTestInstances[1].Event__c, seaTestRegistration.Id);

            //ApexPages.currentPage().getParameters().put('instanceID', seaTestInstances.Id);
            SummitEventsSubmitController submitCtrl = new SummitEventsSubmitController();
            System.assertEquals(submitCtrl.previousPage().getUrl(), '/apex/' + namespace + 'summiteventsregisterappointments');
            System.assertEquals(submitCtrl.submitRegistration().getUrl(), '/apex/' + namespace + 'summiteventsconfirmation');
            Test.stopTest();
        }
    }


    @IsTest static void testSubmitWithFees() {
        SummitEventsTestSharedDataFactory.createContact('TestFirst1', 'TestLast1', 'test1@valleyhill.net', '55418', '(555) 555-5555', '1971-03-22');
        List<Summit_Events_Instance__c> seaTestInstances = SummitEventsTestSharedDataFactory.createTestEvent();
        List<Summit_Events_Fee_Allocation__c> testFeeAllocations = SummitEventsTestSharedDataFactory.AddFeesToEvent(seaTestInstances[1].Event__c);
        SummitEventsTestSharedDataFactory.AddDonationsToEvents(seaTestInstances[1].Event__c, testFeeAllocations);
        Summit_Events_Registration__c seaTestRegistration = SummitEventsTestSharedDataFactory.createEventRegistration(seaTestInstances[1], 'TestFirst', 'TestLast', 'test@valleyhill.net', '55418', '1971-03-22', '2012', null);

        //Get all the variations of user input to make a appointment type for each
        List<String> feeTypes = new List<String>();
        Schema.DescribeFieldResult fieldResult = Summit_Events_Fee__c.Event_Fee_Type__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry pickListVal : ple) {
            feeTypes .add(pickListVal.getLabel());
        }

        List<Summit_Events_Fee__c> testFees = new List<Summit_Events_Fee__c>();
        for (String feeType : feeTypes) {
            Summit_Events_Fee__c fee = new Summit_Events_Fee__c();
            fee.Event_Fee_Type__c = feeType;
            fee.Event_Registration__c = seaTestRegistration.Id;
            fee.Event_Fee__c = 10.00;
            fee.Description__c = feeType + ' Fee';
            testFees.add(fee);
        }
        insert testFees;
        User testUser = SummitEventsTestSharedDataFactory.userToRunWith('Standard User', 'Summit_Events_Registrant');
        String namespace = SummitEventsNamespace.getNamespace();
        if (String.isNotBlank(namespace)) {
            namespace = namespace + '__';
        }
        System.runAs(testUser) {
            Test.startTest();
            PageReference pageRef = Page.SummitEventsSubmit;
            Test.setCurrentPage(pageRef);
            SummitEventsShared SEShared = new SummitEventsShared();
            SEShared.createEncryptedCookie('Transfer', seaTestInstances[1].Id, seaTestInstances[1].Event__c, seaTestRegistration.Id);

            //ApexPages.currentPage().getParameters().put('instanceID', seaTestInstances.Id);
            SummitEventsSubmitController submitCtrl = new SummitEventsSubmitController();
            System.assertEquals(submitCtrl.previousPage().getUrl(), '/apex/' + namespace + 'summiteventsdonation');
            System.assertEquals(submitCtrl.submitRegistration().getUrl(), '/apex/' + namespace + 'summiteventsconfirmation');
            Test.stopTest();
        }

    }

    @IsTest static void testSubmitWithGuestRegistrations() {
        SummitEventsTestSharedDataFactory.createContact('TestFirst1', 'TestLast1', 'test1@valleyhill.net', '55418', '(555) 555-5555', '1971-03-22');
        List<Summit_Events_Instance__c> seaTestInstances = SummitEventsTestSharedDataFactory.createTestEvent();
        Summit_Events_Registration__c seaTestRegistration = SummitEventsTestSharedDataFactory.createEventRegistration(seaTestInstances[1], 'TestFirst', 'TestLast', 'test@valleyhill.net', '55418', '1971-03-22', '2012', null);
        User testUser = SummitEventsTestSharedDataFactory.userToRunWith('Standard User', 'Summit_Events_Registrant');
        String namespace = SummitEventsNamespace.getNamespace();
        if (String.isNotBlank(namespace)) {
            namespace = namespace + '__';
        }

        //Test question with empty map_to_field defined.
        List<Summit_Events_Question__c> testQuestions = SummitEventsTestSharedDataFactory.addQuestionsToEventWithMapTo(seaTestInstances[1].Event__c, 'date', 'Guest', 'Question Text 1', 'Answer_1_Numeric__c');
        testQuestions.addAll(SummitEventsTestSharedDataFactory.addQuestionsToEventWithMapTo(seaTestInstances[1].Event__c, 'Textbox', 'Guest', 'Question Text 5', 'Add_Info_Answer_1__c'));

        //Create question answer JSON object
        List<SummitEventsRegisterGuestsController.questionGuestData> guestsQuestions = new List<SummitEventsRegisterGuestsController.questionGuestData>();
        SummitEventsRegisterGuestsController.questionGuestData guestAnswer = new SummitEventsRegisterGuestsController.questionGuestData();
        List<SummitEventsRegisterGuestsController.questionData> questionsDataList = new List<SummitEventsRegisterGuestsController.questionData>();

        questionsDataList.add(SummitEventsTestSharedDataFactory.createQuestionData(testQuestions[0].Id, 'TEST 0', testQuestions[0].Question_Label__c));
        questionsDataList.add(SummitEventsTestSharedDataFactory.createQuestionData('NOT AN ID', 'TEST NO ID', testQuestions[1].Question_Label__c));

        guestAnswer.guestId = SummitEventsTestSharedDataFactory.getUUID();
        guestAnswer.questions = questionsDataList;
        guestsQuestions.add(guestAnswer);

        seaTestRegistration.Guest_JSON__c = JSON.serialize(guestsQuestions);

        update seaTestRegistration;
        System.runAs(testUser) {
            Test.startTest();
            PageReference pageRef = Page.SummitEventsSubmit;
            Test.setCurrentPage(pageRef);
            SummitEventsShared SEShared = new SummitEventsShared();
            SEShared.createEncryptedCookie('Transfer', seaTestInstances[1].Id, seaTestInstances[1].Event__c, seaTestRegistration.Id);

            //ApexPages.currentPage().getParameters().put('instanceID', seaTestInstances.Id);
            SummitEventsSubmitController submitCtrl = new SummitEventsSubmitController();
            System.assertEquals(submitCtrl.previousPage().getUrl(), '/apex/' + namespace + 'summiteventsregister');
            System.assertEquals(submitCtrl.submitRegistration().getUrl(), '/apex/' + namespace + 'summiteventsconfirmation');
            Test.stopTest();
        }

    }

}