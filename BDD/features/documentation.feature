Feature: Documentation
  In order to learn how to use the system
  The system operator, Oscar
  wants to be able to read about the system in the documentation

  Scenario: EULA Works
    When I go to the "docs/eula" page
    Then the page returns {integer:200}
      And I should see "License"
