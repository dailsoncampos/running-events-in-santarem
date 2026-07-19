require 'rails_helper'

RSpec.describe Runner, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:position) }
    it { should validate_numericality_of(:position).only_integer.is_greater_than(0) }
  end

  describe 'scopes' do
    let(:event) { create(:event) }
    let!(:first_place) { create(:runner, :first_place, event: event) }
    let!(:second_place) { create(:runner, event: event, position: 2) }
    let!(:third_place) { create(:runner, event: event, position: 3) }
    let!(:male_runner) { create(:runner, :male, event: event, position: 4) }
    let!(:female_runner) { create(:runner, :female, event: event, position: 5) }

    describe '.by_position' do
      it 'returns runners ordered by position ascending' do
        runners = Runner.by_position
        expect(runners.first).to eq(first_place)
        expect(runners.second).to eq(second_place)
        expect(runners.third).to eq(third_place)
      end
    end

    describe '.by_gender' do
      it 'returns only male runners when gender is M' do
        runners = Runner.by_gender('M')
        expect(runners).to include(male_runner)
        expect(runners).not_to include(female_runner)
      end

      it 'returns only female runners when gender is F' do
        runners = Runner.by_gender('F')
        expect(runners).to include(female_runner)
        expect(runners).not_to include(male_runner)
      end

      it 'returns all runners when gender is nil' do
        runners = Runner.by_gender(nil)
        expect(runners.count).to eq(5)
      end
    end

    describe '.by_category' do
      let!(:general_runner) { create(:runner, event: event, category: 'OVERALL', position: 6) }
      let!(:veteran_runner) { create(:runner, event: event, category: '40-49', position: 7) }

      it 'returns only runners from specified category' do
        runners = Runner.by_category('OVERALL')
        expect(runners).to include(general_runner)
        expect(runners).not_to include(veteran_runner)
      end

      it 'returns all runners when category is nil' do
        runners = Runner.by_category(nil)
        expect(runners.count).to eq(7)
      end
    end
  end

  describe 'data integrity' do
    it 'stores runner data correctly' do
      event = create(:event)
      runner = create(:runner,
        event: event,
        position: 1,
        bib_number: '001',
        name: 'John Silva',
        club: 'STM Runners',
        gender: 'M',
        category: 'OVERALL',
        finish_time: '00:25:30',
        average_pace: '5:06',
        points: 100,
        laps: 1,
        best_lap: '00:25:30',
        distance: '5000'
      )

      expect(runner.reload).to have_attributes(
        position: 1,
        bib_number: '001',
        name: 'John Silva',
        club: 'STM Runners',
        gender: 'M',
        category: 'OVERALL',
        finish_time: '00:25:30',
        average_pace: '5:06',
        points: 100,
        laps: 1,
        best_lap: '00:25:30',
        distance: '5000'
      )
    end
  end
end
