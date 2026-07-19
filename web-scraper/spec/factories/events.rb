FactoryBot.define do
  factory :event do
    name { "9th Breast Cancer Awareness Run and Walk" }
    event_date { Date.new(2024, 10, 27) }
    city { "Santarém" }
    result_url { "https://www.cronosantarem.com.br/resultados/g-live.html?f=eventos/2024/breast-cancer-run/breast-cancer-run.clax" }
    clax_file_url { "https://www.cronosantarem.com.br/resultados/eventos/2024/breast-cancer-run/breast-cancer-run.clax" }
    scraped_at { nil }

    trait :from_santarem do
      city { "Santarém" }
    end

    trait :from_other_city do
      city { "Belém" }
    end

    trait :cycling do
      name { "10th Mountain Cycling" }
    end

    trait :swimming do
      name { "5th Tapajós River Swimming Crossing" }
    end

    trait :triathlon do
      name { "3rd Santarém Triathlon" }
    end

    trait :scraped do
      scraped_at { Time.current }
    end
  end
end
