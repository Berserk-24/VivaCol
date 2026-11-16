import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vivacol/services/ai_property_search_service.dart';

void main() {
  const listingUrl =
      'https://www.fincaraiz.com.co/apartamento-en-venta/bogota/10733573';

  test('extrae og:image y resuelve una URL relativa', () async {
    final service = AiPropertySearchService(
      client: MockClient((request) async => http.Response(
            '<meta property="og:image" content="/media/property.jpg">',
            200,
            request: request,
          )),
    );
    addTearDown(service.dispose);

    final imageUrl = await service.fetchListingImage(Uri.parse(listingUrl));

    expect(imageUrl, 'https://www.fincaraiz.com.co/media/property.jpg');
  });

  test('usa twitter:image cuando no hay og:image', () async {
    const expectedUrl = 'https://images.example.com/listing.jpg';
    final service = AiPropertySearchService(
      client: MockClient((request) async => http.Response(
            '<meta name="twitter:image" content="$expectedUrl">',
            200,
            request: request,
          )),
    );
    addTearDown(service.dispose);

    final imageUrl = await service.fetchListingImage(Uri.parse(listingUrl));

    expect(imageUrl, expectedUrl);
  });

  test('ignora páginas de otros hosts y respuestas no exitosas', () async {
    final service = AiPropertySearchService(
      client: MockClient((request) async => http.Response(
            '<meta property="og:image" content="https://images.example.com/a.jpg">',
            404,
            request: request,
          )),
    );
    addTearDown(service.dispose);

    final imageUrl = await service.fetchListingImage(Uri.parse(listingUrl));

    expect(imageUrl, isNull);
  });
}
