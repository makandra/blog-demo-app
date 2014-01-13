Feature: CRUD blog posts

@selenium @run_slowly
Scenario: Create blog post
  When I am on the homepage
    And I follow "Posts"
  Then I should see "There are no posts to display."

  # Create
  When I follow "New blog post"
    And I press "Create Post"
  Then I should see "3 errors prohibited this post from being saved"

  When I fill in "Author" with "Max Mustermann"
    And I press "Create Post"
  Then I should see "2 errors prohibited this post from being saved"

  When I fill in "Title" with "Test-Post"
    And I fill in "Description" with "Bla."
    And I press "Create Post"
  Then I should see "1 error prohibited this post from being saved"

  When I fill in "Description" with "Lorem ipsum dolor sit amet, consectetur adipiscing elit."
    And I press "Create Post"
  Then I should see "Post saved successfully"

  # List / Index
  When I follow "Posts"
  Then I should see a table with the following rows:
  | Title     | Description                                              |
  | Test-Post | Lorem ipsum dolor sit amet, consectetur adipiscing elit. |

  # Show
  When I follow "Test-Post"
  Then I should see "Title: Test-Post"
    And I should see "Description: Lorem ipsum dolor sit amet, consectetur adipiscing elit."

  # Update
  When I follow "Edit"
    And I fill in "Author" with ""
    And I press "Update Post"
  Then I should see "1 error prohibited this post from being saved"

  When I fill in "Author" with "Max"
    And I press "Update Post"
  Then I should see "Post saved successfully"

  # Delete
  When I follow "Delete"
    And I confirm the browser dialog
  Then I should see "Post deleted successfully"
