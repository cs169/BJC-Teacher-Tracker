class AddVerificationNotesToTeachers < ActiveRecord::Migration[6.1]
  def change
    # This migration adds an OPTIONAL free-form notes field used during teacher
    # verification review.
    #
    # Why this is a text column:
    # - The product requirement asks for a notes field where users can provide
    #   additional verification context (for example, principal/admin contact
    #   details or homeschool verification details).
    # - That content can be longer and more variable than a typical short string,
    #   so `text` provides safer headroom without imposing an arbitrary limit.
    #
    # Why this is nullable:
    # - The field is explicitly optional in the feature request.
    # - Existing teacher records should remain valid without backfilling any value.
    # - New teacher records can omit this field and still be created normally.
    #
    # Rollback behavior:
    # - Because we use `change`, Rails can automatically reverse this migration
    #   by removing the column when rolling back.
    add_column :teachers, :verification_notes, :text
  end
end
