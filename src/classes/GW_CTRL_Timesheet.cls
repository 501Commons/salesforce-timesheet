/*******************************************************************************************************
* @author David Habib
* @date 7/1/2011
* @description Page Controller class for the timesheet visualforce page.  Provides Javascript remoting
* methods for getting data (Accounts, Projects (opportunities), Tasks, TaskLogs), and for saving 
* TaskLog records.
*
* Written by Dave Habib, copyright (c) 2011 Groundwire
* This program is released under the GNU Affero General Public License, Version 3. http://www.gnu.org/licenses/
********************************************************************************************************/
global with sharing class GW_CTRL_Timesheet {

        private static ID rtIdProject = GW_RecTypes.GetRecordTypeId('Opportunity', 'Consulting Project - Hourly');
        public static list<string> EXCLUDED_STAGES_FOR_TIMETRACKING = new list<string>{'Prospecting','Planning','Closure','Terminated','Application Review','Locked'};

        public GW_CTRL_Timesheet() {

        }
 

        /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Accounts, optionally filtered by strFilter.
        * @param strFilter the substring to filter by 
        * @return list<Account>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<Account> getListAccounts(string strFilter, string subID) {
        
        list<Account> listAccounts = new list<Account>();
        
        User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()]; 
        ID userContact = thisUser.contact_Id__c;
        if(/* userContact == Null &&*/ subID != Null && subID != '') {
          System.debug(' ******: Sub ID is '+subID);
          List<Contact> contacts = [SELECT Id FROM Contact WHERE Subcontractor_PIN__c = :subID];
          System.debug(' ****** sub id contacts size: ' + contacts.size());
          if(contacts.size() > 0) {
            userContact = contacts.get(0).Id;
          }
          System.debug(' ****** sub id contacts id: ' + userContact);
        }
        
        strFilter = '%' + strFilter + '%';
        list<OpportunityContactRole> crs = [SELECT Id, OpportunityId, ContactId FROM OpportunityContactRole WHERE ContactId = :userContact];
        list<Id> OpIds = new list<Id>();
        
        if (!crs.isEmpty()) {
                for (OpportunityContactRole cr : crs) {
                        OpIds.add(cr.OpportunityId);
                }
                listAccounts = [select Id, Name from Account where 
                                    Name like :strFilter and
                                        Id in (select AccountId from Opportunity where RecordTypeId = :rtIdProject and Id IN :OpIds) 
                                    order by Name asc];
        }            
        return listAccounts;
    }           
        
        /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Projects, which are Opportunities,
        * filtered by the accountId and strFilter.
        * @param accountId the accountId to filter projects by
        * @param strFilter the substring to filter by 
        * @return list<Opportunity>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<Opportunity> getListOppProjects(string accountId, string strFilter, string subID) {
        if (accountId == null || accountId == '') return null;
        strFilter = '%' + strFilter + '%';
                
                User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()]; 
        ID userContact = thisUser.contact_Id__c;
        if(userContact == Null && subID != Null && subID != '') {
          List<Contact> contacts = [SELECT Id FROM Contact WHERE Subcontractor_PIN__c = :subID];
          if(contacts.size() > 0) {
            userContact = contacts.get(0).Id;
          }
        }

        list<OpportunityContactRole> crs = [SELECT Id, OpportunityId, ContactId FROM OpportunityContactRole WHERE ContactId = :userContact];
        list<Id> OpIds = new list<Id>();
        
        list<Opportunity> listOppProjects = new list<Opportunity>();
        
        if (!crs.isEmpty()) {
                for (OpportunityContactRole cr : crs) {
                        OpIds.add(cr.OpportunityId);
                }
                
                listOppProjects = [select Id, Name, Staff_Hours_Actual__c, Project_Category__c from Opportunity where 
                                                 AccountId = :accountId and
                                                 Id IN :OpIds and
                                     RecordTypeId=:rtIdProject and 
                                         Name like :strFilter and
                                         stagename NOT IN :GW_CTRL_Timesheet.EXCLUDED_STAGES_FOR_TIMETRACKING order by Name asc];
         }               
         return listOppProjects;
    }
    
    /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Project Phases, which are options,
        * the Project_Phase__c field.
        * @return list<String>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<string> getProjectPhases() {
        list<string> plist = new list<String>();
                for (Schema.PicklistEntry value : Project_Time_Log__c.Project_Phase__c.getDescribe().getPicklistValues() )
                        plist.add((string)value.getvalue());
                return plist;
    }           

        /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Tasks, filtered by the projectId and strFilter.
        * @param projectId the projectId (Opportunity ID) to filter projects by
        * @param isAdHoc whether the project is of Category Type 'Ad Hoc'
        * @param strFilter the substring to filter by 
        * @return list<Project_Role__c>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<Project_Role__c> getListTasks(string projectId, boolean isAdHoc, string strFilter) {
        if ((projectId == null || projectId == '') && !isAdHoc) return null;
        strFilter = '%' + strFilter + '%';   
        list<Project_Role__c> listTasks = [select Id, Name from Project_Role__c where 
                        Project__c = :projectId and Active__c = true and 
                                Name like :strFilter 
                                order by Name asc];
                        
                return listTasks;
    }   

        /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Common Tasks for Groundwire Staff,
        * which are defined as all tasks under a General Program opportunity for account Groundwire.
        * @param iLimit maximum items to return.
        * @return list<Project_Role__c>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<Project_Role__c> getListCommonRoles(integer iLimit) {
        list<Project_Role__c> listRoles = [select Id, Name, Project__r.AccountId, Project__r.Account.Name, 
                        Project__c, Project__r.Name from Project_Role__c where Active__c = true  
                                order by Name asc limit :iLimit];
                        
                return listRoles;
    }
    

        /*******************************************************************************************************
        * @description Javascript Remoting method to return a list of Task Logs, filtered by the start and
        * end dates, for the given logged in user.
        * &param strStartDate filter for Logs >= startDate
        * &param strEndDate filter for Logs <= endDate
        * @return list<Project_Time_Log__c>, which will be turned into a Javascript collection.
        ********************************************************************************************************/
    @RemoteAction global static list<Project_Time_Log__c> getListLogs(string strStartDate, string strEndDate, string mode, string subID) {
        Date startDate = date.valueOf(strStartDate);
        Date endDate = date.valueOf(strEndDate);

                // when I tried caching these in the constructor, they didn't seem to work.
                User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()]; 
                ID creatorId = thisUser.contact_Id__c;  
                list<Project_Time_Log__c> listLogs;
                if(creatorId == Null && subID != Null && subID != '') {
                  List<Contact> contacts = [SELECT Id FROM Contact WHERE Subcontractor_PIN__c = :subID];
                  if(contacts.size() > 0) {
                    creatorId = contacts.get(0).Id;
                  }
                }                                
                if (mode == 'Actual') {
                        listLogs = [select Id, Staff_Person__c, Name, Project_Role__r.Project__r.AccountId, Project_Role__r.Project__r.Account.Name,
                        Project_Role__r.Project__c, Project_Role__r.Project__r.Name, Project_Role__r.Project__r.Project_Category__c, 
                        Project_Role__r.Project__r.Staff_Hours_Actual__c,
                        Project_Role__c, Project_Role__r.Name, Project_Phase__c,
                        Date__c, Actual_Hours__c, Projected_Hours__c, Time_Log_Description__c, Billable__c
                        from Project_Time_Log__c 
                        where Staff_Person__c = :creatorId and
                        Date__c >= :startDate and 
                        Date__c <= :endDate and
                        Actual_Hours__c > 0
                        order by Date__c, Project_Role__r.Project__r.Account.Name, Project_Role__r.Project__r.Name
                        ];
                } else if (mode == 'Planning') {
                        listLogs = [select Id, Staff_Person__c, Name, Project_Role__r.Project__r.AccountId, Project_Role__r.Project__r.Account.Name,
                        Project_Role__r.Project__c, Project_Role__r.Project__r.Name, Project_Role__r.Project__r.Project_Category__c, 
                        Project_Role__r.Project__r.Staff_Hours_Actual__c,
                        Project_Role__c, Project_Role__r.Name, Project_Phase__c,
                        Date__c, Actual_Hours__c, Projected_Hours__c, Time_Log_Description__c, Billable__c
                        from Project_Time_Log__c 
                        where Staff_Person__c = :creatorId and
                        Date__c >= :startDate and 
                        Date__c <= :endDate and
                        Projected_Hours__c > 0
                        order by Date__c, Project_Role__r.Project__r.Account.Name, Project_Role__r.Project__r.Name
                        ];
                    
                        
                }
                return listLogs;                 
    }           
    /*******************************************************************************************************
    * @description Javascript Remoting method to Update or Insert a Task Log record.
    * @param strStartDate - Filter time logs to within range
    * @param strEndDate
    * @return integer, number of projected hours
    ********************************************************************************************************/
    @RemoteAction global static list<AggregateResult> getProjectedSum(string strStartDate, string strEndDate, string subID) {
        
        Date startDate = date.valueOf(strStartDate);
        Date endDate = date.valueOf(strEndDate);
        
        // when I tried caching these in the constructor, they didn't seem to work.
        User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()]; 
        ID creatorId = thisUser.contact_Id__c;  
        if(creatorId == Null && subID != Null && subID != '') {
           List<Contact> contacts = [SELECT Id FROM Contact WHERE Subcontractor_PIN__c = :subID];
           if(contacts.size() > 0) {
              creatorId = contacts.get(0).Id;
           }
        }                                
        list<AggregateResult> projectedSum;
                
        projectedSum = [SELECT SUM(Projected_Hours__c)sum FROM Project_Time_Log__c WHERE Staff_Person__c = :creatorId AND Date__c >= :startDate and Date__c <= :endDate and Projected_Hours__c > 0];
                
        return projectedSum;
                
    }
        
        /*******************************************************************************************************
        * @description Javascript Remoting method to Update or Insert a Task Log record.
        * @param accountId
        * @param projectId
        * @param accountId
        * @param taskId
        * @param logId ignored if !isUpdate
        * @param strLogName 
        * @param strDate
        * @param hours
        * @param strNotes
        * @param isUpdate
        * @param isBillable
        * @return string, which is null if the save was successful, and contains an error message if failed.
        ********************************************************************************************************/
        @RemoteAction global static string strSaveLog(string accountId, string projectId, string taskId, string logId, 
        string strLogName, string strDate, string strPhase, double hours, double projected, string strNotes, boolean isUpdate, boolean isBillable, string subID) {
          try {
            Project_Time_Log__c log;
            // when I tried caching these in the constructor, they didn't seem to work.
            User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()];
            ID creatorId = thisUser.contact_Id__c;
            if(creatorId == Null && subID != Null && subID != '') {
              List<Contact> contacts = [SELECT Id FROM Contact WHERE Subcontractor_PIN__c = :subID];
              if(contacts.size() > 0) {
                creatorId = contacts.get(0).Id;
              }
            }                                                        
            //get the currency from the Project Role
            Project_Role__c logRole = [SELECT id FROM Project_Role__c WHERE Id = :taskId];  
            
            if (!isUpdate) {
              log = new Project_Time_Log__c(Project_Role__c = taskId);
            } else {
              log  = [select Id, Staff_Person__c, Project_Role__r.Project__r.AccountId, Project_Role__r.Project__c, Project_Role__c, 
                Date__c, Actual_Hours__c, Time_Log_Description__c from Project_Time_Log__c 
                where Id = :logId limit 1];             
              
              // handle the user changing the task, which requires us to recreate the log.
              if (taskId != log.Project_Role__c)      {
                delete log;
                log = new Project_Time_Log__c(Project_Role__c = taskId);
                isUpdate = false;
              }                                                                               
            }
            
            log.Staff_Person__c = creatorId;
            log.Project__c = projectId;
            log.Date__c = date.valueOf(strDate);
            log.Project_Phase__c = strPhase;
            log.Actual_Hours__c = hours;
            log.Projected_Hours__c = projected;
            log.Time_Log_Description__c = strNotes;
            log.Billable__c = isBillable;
            
            if (!isUpdate)
            insert log;
            else
            update log;
            return null;
          } catch(exception ex) {
            return ex.getMessage();
          }
        }
        
        /*******************************************************************************************************
        * @description Javascript Remoting method to delete a Task Log record.
        * @param logId the task Log to delete
        * @return string, which is null if the del was successful, and contains an error message if failed.
        ********************************************************************************************************/
        @RemoteAction global static string strDeleteLog(string logId) {
                try {
                        Project_Time_Log__c log;
                        log  = [select Id from Project_Time_Log__c where Id = :logId limit 1];
                        delete log;
                        return null;            
                } catch(exception ex) {
                        return ex.getMessage();
                }
        }


/******************************************************************************************************
* TEST CODE
********************************************************************************************************/
static testmethod void tests() {
                
    User thisUser = [Select contact_id__c from user where id = :UserInfo.getUserId()];
    ID creatorId = thisUser.contact_Id__c;  
                
    Account acc = new account(name='testacct');
    insert acc;             
    
    Opportunity oppProject = new Opportunity (
            Name = 'Test Project',
            recordTypeId = rtIdProject,
            accountid = acc.Id,
            StageName='Delivery',
            CloseDate=system.today()
    );
    insert oppProject;
    
    OpportunityContactRole oppConRole = new OpportunityContactRole(
        ContactId = creatorId,
        OpportunityId = oppProject.Id
        );
    insert oppConRole;
    
    Project_Role__c projectTask = new Project_Role__c(
            Name = 'My New Project Task',
            Project__c = oppProject.Id,
            Accounting_Class__c = 'Consulting',
            Active__c = true
            );
    insert projectTask;
    
    Project_Role__c projectTask2 = new Project_Role__c(
            Name = 'My New Project Task 2',
            Project__c = oppProject.Id,
            Accounting_Class__c = 'Consulting',
            Active__c = true
            );
    insert projectTask2;

    Project_Time_Log__c logNew = new Project_Time_Log__c(
            Project_Role__c = projectTask.Id,
            Project__c = oppProject.Id,
            Date__c = system.today(),
            Time_Log_Description__c = 'this is my test log',
            Actual_Hours__c = 5,
            Staff_Person__c = creatorId
            );
    insert logNew;
    
    PageReference pageRef = Page.timesheet; 
        Test.setCurrentPage(pageRef); 
        GW_CTRL_Timesheet ctrl = new GW_CTRL_Timesheet();
        
        list<Account> listA = getListAccounts('', '');
        system.assert(listA.size() > 0);
        list<Opportunity> listP = getListOppProjects(acc.Id, '', '');
    system.assertEquals(1, listP.size());        
        list<Project_Role__c> listT = getListTasks(oppProject.Id, false, '');
    system.assertEquals(2, listT.size());        
        
        //this just pulls tasks/roles from the General Program bucket, and we should change this method to 
        //get the most recent tasks. In the meantime, I'm just commmenting this assertion out until refactored
        list<Project_Role__c> listCT = getListCommonRoles(1);
    //system.assertEquals(1, listCT.size());
        listCT = getListCommonRoles(100);
    //system.assert(listCT.size() > 0); 
    
    list<Project_Time_Log__c> listL = getListLogs(string.valueOf(system.today()), string.valueOf(system.today()), 'Actual','');
    system.assert(listL.size() > 0);
    integer cLogs = listL.size();
    string str = strSaveLog(string.valueOf(acc.Id), 
            string.valueOf(oppProject.Id),
            string.valueOf(projectTask.Id), 
            '', 'my log name', string.valueOf(system.today()), 'Design', 2,5, 'my notes that are unique for this test!', false, false, '');
    system.assertEquals(null, str);
    listL = getListLogs(string.valueOf(system.today()), string.valueOf(system.today()), 'Actual','');
    system.assertEquals(cLogs + 1, listL.size());
    //system.assertEquals('my notes that are unique for this test!', listL[cLogs].Time_Log_Description__c);
    str = strSaveLog(string.valueOf(acc.Id), 
            string.valueOf(oppProject.Id),
            string.valueOf(projectTask.Id), 
            string.valueOf(listL[cLogs].Id),
            'my log name',  
            string.valueOf(system.today()), 'Design', 2,6, 'different notes for this test!', true, false,'');
    system.assertEquals(null, str); 
    str = strSaveLog(string.valueOf(acc.Id), 
            string.valueOf(oppProject.Id),
            string.valueOf(projectTask2.Id), 
            string.valueOf(listL[cLogs].Id),
            'my log name',  
            string.valueOf(system.today()), 'Design', 2,6, 'different notes for this test!', true, false,'');
    system.assertEquals(null, str);             
    listL = getListLogs(string.valueOf(system.today()), string.valueOf(system.today()), 'Actual','');
    system.assertEquals(cLogs + 1, listL.size());
    str = strDeleteLog(listL[cLogs].Id);
    system.assertEquals(null, str);
    listL = getListLogs(string.valueOf(system.today()), string.valueOf(system.today()), 'Actual','');
    system.assertEquals(cLogs, listL.size());
                                        
        }       
                
}