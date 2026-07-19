FactoryBot.define do
  factory :runner do
    association :event
    sequence(:position) { |n| n }
    sequence(:bib_number) { |n| n.to_s.rjust(3, '0') }
    name { Faker::Name.name }
    club { "Santarém Runners Association" }
    gender { %w[M F].sample }
    category { %w[OVERALL U23 40-49 50-59 60+].sample }
    finish_time { "00:#{rand(30..59)}:#{rand(10..59)}" }
    average_pace { "#{rand(4..7)}:#{rand(10..59)}" }
    points { rand(80..100) }
    laps { 1 }
    best_lap { "00:#{rand(30..59)}:#{rand(10..59)}" }
    distance { "5000" }

    trait :male do
      gender { "M" }
    end

    trait :female do
      gender { "F" }
    end

    trait :first_place do
      position { 1 }
      finish_time { "00:20:15" }
    end
  end
end
