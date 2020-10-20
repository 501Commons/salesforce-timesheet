@isTest
public class volSkillsSearchTestClass {
    public static testMethod void testVolSkillsSearch() {
        
        PageReference pageRef = Page.VolunteerSkillSearch;
        Test.setCurrentPage(pageRef);    

        
        // create test records
    Contact contact = new Contact(LastName='Tester');
        insert contact;
        
   Product2 product = new Product2(Name='FIN Grants Administration', IsActive=True, Include_in_Web_to_Lead_form__c=False);
        insert product;
        
    gaia_esc_Volunteer_Skill__c skill = new gaia_esc_Volunteer_Skill__c (Contact__c = contact.Id, Product__c = product.Id, Skill_Level__c='Expert'); // ,Name = 'Tester Skill');
        insert skill;
        
     // create a new standard controller by passing it the skill record
    ApexPages.StandardController controller = new ApexPages.StandardController(skill);

    // now pass it to the extension
      volSkillSearchController pag = new volSkillSearchController(controller); 
             
        string searchquery= 'SELECT name, skill_level__c FROM gaia_esc_Volunteer_Skill__c';        
        pag.prod = Database.query(searchquery);
    
      // System asserts
                       
      system.assert(pag != null); // controller has successfully been created
      system.assert(pag.getLevels() != null); // method is valid
      system.assert(pag.getItems() != null); // method is valid
      system.assert(pag.getFamilies() != null); // method is valid  
     // system.assertEquals('Tester Skill', pag.prod[0].name); // my test record can be found
          
              
    }
             
}