class RepositoryTableState < ApplicationRecord
  belongs_to :user, inverse_of: :repository_table_states, optional: true
  belongs_to :repository, inverse_of: :repository_table_states, optional: true

  validates :user, :repository, presence: true

  # We're using Constants::REPOSITORY_TABLE_DEFAULT_STATE as a reference for
  # default table state; this Ruby Hash makes heavy use of Ruby symbols
  # notation; HOWEVER, the state that is saved on the RepositoryTableState
  # record, has EVERYTHING (booleans, symbols, keys, ...) saved as Strings.

  def self.load_state(user, repository)
    state = where(user: user, repository: repository).take
    if state.blank?
      state = RepositoryTableState.create_state(user, repository)
    end
    state
  end

  def self.update_state(custom_column, column_index, user)
    # table state of every user having access to this repository needs udpating
    table_states = RepositoryTableState.where(
      repository: custom_column.repository
    )
    table_states.each do |table_state|
      repository_state = table_state['state']
      if column_index
        # delete column
        repository_state['columns'].delete(column_index)
        repository_state['columns'].keys.each do |index|
          if index.to_i > column_index.to_i
            repository_state['columns'][(index.to_i - 1).to_s] =
              repository_state['columns'].delete(index)
          else
            index
          end
        end

        repository_state['ColReorder'].delete(column_index)
        repository_state['ColReorder'].map! do |index|
          if index.to_i > column_index.to_i
            (index.to_i - 1).to_s
          else
            index
          end
        end
      else
        # add column
        index = repository_state['columns'].count
        repository_state['columns'][index] =
          Constants::REPOSITORY_TABLE_DEFAULT_STATE[:columns].first
        repository_state['ColReorder'].insert(2, index.to_s)
      end
      table_state.update(state: repository_state)
    end
  end

  def self.create_state(user, repository)
    default_columns_num =
      Constants::REPOSITORY_TABLE_DEFAULT_STATE[:length]

    # This state should be strings-only
    state = HashUtil.deep_stringify_keys_and_values(
      Constants::REPOSITORY_TABLE_DEFAULT_STATE
    )
    repository.repository_columns.each_with_index do |_, index|
      real_index = default_columns_num + index
      state['columns'][real_index.to_s] =
        HashUtil.deep_stringify_keys_and_values(
          Constants::REPOSITORY_TABLE_STATE_CUSTOM_COLUMN_TEMPLATE
        )
      state['ColReorder'] << real_index.to_s
    end
    state['length'] = state['columns'].length.to_s
    state['time'] = Time.new.to_i.to_s
    return RepositoryTableState.create(user: user,
                                       repository: repository,
                                       state: state)
  end
end
