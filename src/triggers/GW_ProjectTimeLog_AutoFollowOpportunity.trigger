// trigger to automatically have users related to time log follow the related opportunity
trigger GW_ProjectTimeLog_AutoFollowOpportunity on Project_Time_Log__c (after insert, after update) {
    
    map<id,set<id>> projectConsMap = new map<id,set<id>>();
    
    list<EntitySubscription> subscriptions = new list<EntitySubscription>();
    
    for(Project_Time_Log__c log : trigger.new) {
        if (log.Staff_Person__c != null && log.Project__c != null) {
            if(!projectConsMap.containsKey(log.Staff_Person__c)) {
                projectConsMap.put(log.Staff_Person__c,new set<id>());
            } 
            projectConsMap.get(log.Staff_Person__c).add(log.Project__c);
        }
    }
    system.debug('Contact Map: '+ projectConsMap);
    
    User[] users = [SELECT id, Contact_Id__c FROM User]; 
    
    system.debug('Users: '+ users);
    for(user u : users) {
    	id myid = u.Contact_Id__c;
        if (projectConsMap.get(myid) != null) {
	        for (id thisProject : projectConsMap.get(u.Contact_id__c)) {
	            subscriptions.add(new EntitySubscription(SubscriberId=u.id,ParentId=thisProject)); 
	        }
        }
    }
    system.debug('subscriptions: '+ subscriptions);
    if (!subscriptions.isEmpty()) {
        database.insert(subscriptions,false);
    }
}