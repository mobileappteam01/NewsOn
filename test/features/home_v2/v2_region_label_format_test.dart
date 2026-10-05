import 'package:flutter_test/flutter_test.dart';
import 'package:newson/features/home_v2/domain/home_filter_state.dart';
import 'package:newson/features/home_v2/domain/v2_home_metadata.dart';

void main() {
  group('formatRegionLabel', () {
    test('single word', () {
      expect(formatRegionLabel('india'), 'India');
      expect(formatRegionLabel('erode'), 'Erode');
    });

    test('multiple words', () {
      expect(formatRegionLabel('south korea'), 'South Korea');
      expect(formatRegionLabel('tamil nadu'), 'Tamil Nadu');
      expect(formatRegionLabel('new delhi'), 'New Delhi');
      expect(formatRegionLabel('erode district'), 'Erode District');
      expect(formatRegionLabel('  tamil   nadu '), 'Tamil Nadu');
    });

    test('mixed casing', () {
      expect(formatRegionLabel('tAMIL nADU'), 'Tamil Nadu');
      expect(formatRegionLabel('SOUTH KOREA'), 'South Korea');
      expect(formatRegionLabel('jammu-kashmir'), 'Jammu-Kashmir');
    });

    test('empty / null', () {
      expect(formatRegionLabel(null), '');
      expect(formatRegionLabel(''), '');
      expect(formatRegionLabel('   '), '');
    });

    test('already formatted, acronyms and localized names are kept', () {
      expect(formatRegionLabel('Tamil Nadu'), 'Tamil Nadu');
      expect(formatRegionLabel('McAllen'), 'McAllen');
      expect(formatRegionLabel('UAE'), 'UAE');
      expect(formatRegionLabel('NCR region'), 'NCR Region');
      expect(formatRegionLabel('தமிழ்நாடு'), 'தமிழ்நாடு');
      expect(formatRegionLabel('नई दिल्ली'), 'नई दिल्ली');
      expect(formatRegionLabel('ಕರ್ನಾಟಕ'), 'ಕರ್ನಾಟಕ');
    });

    test('display only: filter values and feed key keep backend slugs', () {
      const filter = HomeFilterState(
        country: 'south korea',
        state: 'tamil nadu',
        district: 'erode district',
      );
      expect(filter.country, 'south korea');
      expect(filter.state, 'tamil nadu');
      expect(filter.district, 'erode district');
      expect(formatRegionLabel(filter.state), 'Tamil Nadu');
      expect(filter.state, 'tamil nadu');
    });

    test('V2RegionOption name stays as sent by the backend', () {
      final option = V2RegionOption.fromJson({
        'slug': 'tamil-nadu',
        'name': 'tamil nadu',
      });
      expect(option.slug, 'tamil-nadu');
      expect(option.name, 'tamil nadu');
      expect(formatRegionLabel(option.name), 'Tamil Nadu');
    });
  });
}
