module ImportRepository
  class ImportRecords
    def initialize(options)
      @temp_file = options.fetch(:temp_file)
      @repository = options.fetch(:repository)
      @mappings = options.fetch(:mappings)
      @session = options.fetch(:session)
      @user = options.fetch(:user)
    end

    def import!(can_edit_existing_items, should_overwrite_with_empty_cells)
      status = run_import_actions(can_edit_existing_items, should_overwrite_with_empty_cells)
      @temp_file.destroy
      status
    end

    private

    def run_import_actions(can_edit_existing_items, should_overwrite_with_empty_cells)
      @temp_file.file.open do |temp_file|
        @repository.import_records(
          SpreadsheetParser.open_spreadsheet(temp_file),
          @mappings,
          @user,
          can_edit_existing_items,
          should_overwrite_with_empty_cells
        )
      end
    end

    def run_checks
      unless @mappings
        return {
          status: :error,
          errors:
            I18n.t('repositories.import_records.error_message.no_data_to_parse')
        }
      end
      unless @mappings.value?('-1')
        return {
          status: :error,
          errors:
            I18n.t('repositories.import_records.error_message.no_column_name')
        }
      end
      unless @temp_file
        return {
          status: :error,
          errors:
            I18n.t(
              'repositories.import_records.error_message.temp_file_not_found'
            )
        }
      end
      unless @temp_file.session_id == session.id
        return {
          status: :error,
          errors:
            I18n.t('repositories.import_records.error_message.session_expired')
        }
      end
    end
  end
end
