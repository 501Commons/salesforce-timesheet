trigger GW_ProjectRole_BeforeTrigger on Project_Role__c (before insert, before update) {
    
    //calculate the projected, budgeted, and actual amounts based on the hourly rate
    for (Project_Role__c role : trigger.new) {
    	
        if (role.Hourly_Rate__c > 0) {
            role.Budgeted_Amount__c = (role.Budgeted_Hours__c > 0) ? role.Budgeted_Hours__c * role.Hourly_Rate__c : 0;
            role.Projected_Amount__c = (role.Projected_Hours__c > 0) ? role.Projected_Hours__c * role.Hourly_Rate__c : 0;
            role.Actual_Amount__c = (role.Actual_Hours__c > 0) ? role.Actual_Hours__c * role.Hourly_Rate__c : 0;
        } else {
            role.Budgeted_Amount__c = 0;
            role.Projected_Amount__c = 0;
            role.Actual_Amount__c = 0;
        }
        Decimal over = (role.Actual_Amount_Override__c != Null) ? role.Actual_Amount_Override__c : 0;
        if (Math.abs(over) > 0) {
    		role.Actual_Amount__c = role.Actual_Amount_Override__c;
    	}
    } 
    
}