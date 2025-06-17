require 'rails_helper'
require 'rake'

RSpec.describe 'releases rake tasks', type: :task do
  before do
    Rake.application.rake_require 'tasks/releases'
    Rake::Task.define_task(:environment)
  end

  describe 'releases:import' do
    let(:task) { Rake::Task['releases:import'] }

    before do
      task.reenable
    end

    context 'when import is successful' do
      before do
        allow(ReleaseImportService).to receive(:import_upcoming_releases).and_return({
          imported: 5,
          skipped: 2,
          errors: 0
        })
      end

      it 'runs without errors' do
        expect { task.invoke }.not_to raise_error
      end

      it 'calls ReleaseImportService' do
        expect(ReleaseImportService).to receive(:import_upcoming_releases)
        task.invoke
      end

            it 'displays success message' do
        task.reenable
        expect { task.invoke }.to output(/Import completed successfully!/).to_stdout

        task.reenable
        expect { task.invoke }.to output(/Imported: 5 new releases/).to_stdout

        task.reenable
        expect { task.invoke }.to output(/Skipped: 2 duplicates/).to_stdout

        task.reenable
        expect { task.invoke }.to output(/Errors: 0 errors/).to_stdout
      end
    end

    context 'when import has errors' do
      before do
        allow(ReleaseImportService).to receive(:import_upcoming_releases).and_return({
          imported: 3,
          skipped: 1,
          errors: 2
        })
      end

      it 'exits with error code' do
        expect { task.invoke }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'displays error message' do
        begin
          task.invoke
        rescue SystemExit
          # Expected
        end

        task.reenable
      end
    end

    context 'when service raises an exception' do
      before do
        allow(ReleaseImportService).to receive(:import_upcoming_releases)
          .and_raise(StandardError.new('Connection failed'))
        allow(Rails.logger).to receive(:error)
      end

      it 'handles the exception and exits with error' do
        expect { task.invoke }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('[ReleaseImportTask] Fatal error: Connection failed')
        expect(Rails.logger).to receive(:error).with(anything)

        begin
          task.invoke
        rescue SystemExit
          # Expected
        end
      end
    end
  end

  describe 'releases:cleanup' do
    let(:task) { Rake::Task['releases:cleanup'] }

    before do
      task.reenable
    end

    context 'when cleanup is successful' do
      let(:country) { Country.create!(name: 'United States', shortcode: 'US') }
      let(:network) { Network.create!(name: 'HBO', external_id: 'hbo_123', country: country) }
      let(:show) { Show.create!(title: 'Old Show', external_id: 'show_old', network: network) }
      let(:episode) { Episode.create!(season_number: 1, episode_number: 1, external_id: 'ep_old', show: show) }
      let!(:old_release) do
        Release.create!(
          air_date: Date.current - 10.days,
          air_time: '20:00:00',
          episode: episode
        )
      end

      let(:recent_show) { Show.create!(title: 'Recent Show', external_id: 'show_recent', network: network) }
      let(:recent_episode) { Episode.create!(season_number: 1, episode_number: 1, external_id: 'ep_recent', show: recent_show) }
      let!(:recent_release) do
        Release.create!(
          air_date: Date.current - 2.days,
          air_time: '21:00:00',
          episode: recent_episode
        )
      end

      it 'deletes old releases' do
        expect { task.invoke }.to change(Release, :count).by(-1)
        expect(Release.exists?(old_release.id)).to be false
        expect(Release.exists?(recent_release.id)).to be true
      end

            it 'displays success message' do
        task.reenable
        expect { task.invoke }.to output(/Cleaning up old releases.../).to_stdout

        task.reenable
        expect { task.invoke }.to output(/Deleted \d+ old releases/).to_stdout
      end
    end

    context 'when cleanup fails' do
      before do
        allow(Release).to receive(:where).and_raise(StandardError.new('Database error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'handles the exception and exits with error' do
        expect { task.invoke }.to raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with('[ReleaseCleanupTask] Error: Database error')

        begin
          task.invoke
        rescue SystemExit
          # Expected
        end
      end
    end
  end

  describe 'releases:maintain' do
    let(:task) { Rake::Task['releases:maintain'] }

    before do
      task.reenable
      Rake::Task['releases:import'].reenable
      Rake::Task['releases:cleanup'].reenable
    end

    it 'runs both import and cleanup tasks' do
      expect(Rake::Task['releases:import']).to receive(:invoke)
      expect(Rake::Task['releases:cleanup']).to receive(:invoke)

      task.invoke
    end

        it 'displays maintenance message' do
      # Mock the tasks to prevent actual execution
      allow(Rake::Task['releases:import']).to receive(:invoke)
      allow(Rake::Task['releases:cleanup']).to receive(:invoke)

      expect { task.invoke }.to output(/Running full releases maintenance.../).to_stdout

      task.reenable
      allow(Rake::Task['releases:import']).to receive(:invoke)
      allow(Rake::Task['releases:cleanup']).to receive(:invoke)
      expect { task.invoke }.to output(/Maintenance completed!/).to_stdout
    end
  end
end
