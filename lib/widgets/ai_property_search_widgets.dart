import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/ai_property_search.dart';
import '../providers/ai_property_search_provider.dart';
import '../providers/auth_provider.dart';
import '../services/saved_ai_listings_repository.dart';
import '../theme/app_colors.dart';
import '../utils/format.dart';

class AiPropertySearchResults extends StatelessWidget {
  final AiPropertySearchProvider search;

  const AiPropertySearchResults({super.key, required this.search});

  @override
  Widget build(BuildContext context) {
    final response = search.response;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AiSearchBanner(request: search.request, response: response),
        if (search.loading) const LinearProgressIndicator(minHeight: 2),
        if (response?.hint case final hint?)
          _SearchNotice(icon: Icons.tips_and_updates_outlined, text: hint),
        if (search.error case final error?)
          _SearchNotice(icon: Icons.error_outline, text: error),
        if (response?.message case final message?)
          _SearchNotice(icon: Icons.info_outline, text: message),
        for (final listing
            in response?.listings ?? const <AiPropertySearchListing>[])
          AiPropertySearchListingCard(
            key: ValueKey(listing.url),
            listing: listing,
          ),
        if (!kIsWeb && response?.grounded == true)
          if (response?.searchEntryPointHtml case final html?)
            _GoogleSearchSuggestions(html: html),
      ],
    );
  }
}

class _AiSearchBanner extends StatelessWidget {
  final String request;
  final AiPropertySearchResponse? response;

  const _AiSearchBanner({required this.request, required this.response});

  @override
  Widget build(BuildContext context) {
    final interpretation = response?.interpretation;
    final title = interpretation == null
        ? 'Buscando en Bogotá: $request'
        : 'Buscando ${interpretation.propertyType} en '
            '${interpretation.operation}'
            '${interpretation.maxPrice == null ? '' : ' hasta ${formatPrice(interpretation.maxPrice!.toDouble())}'}'
            '${interpretation.zone == null ? '' : ' en ${interpretation.zone}'}';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusReviewBg,
        border: Border.all(
            color:
                const Color.fromARGB(255, 71, 81, 133).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.statusReview),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(color: AppColors.darkGray),
                ),
              ),
            ],
          ),
          if (interpretation?.assumptions case final assumptions?
              when assumptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Supuestos: ${assumptions.join('; ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchNotice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SearchNotice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.mediumGray),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.darkGray),
            ),
          ),
        ],
      ),
    );
  }
}

class AiPropertySearchListingCard extends StatefulWidget {
  final AiPropertySearchListing listing;

  const AiPropertySearchListingCard({
    super.key,
    required this.listing,
  });

  @override
  State<AiPropertySearchListingCard> createState() =>
      _AiPropertySearchListingCardState();
}

class _AiPropertySearchListingCardState
    extends State<AiPropertySearchListingCard> {
  String? _imageUrl;
  bool _requestedImage = false;
  bool _requestedSavedState = false;
  bool _isSaved = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedSavedState) {
      _requestedSavedState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSavedState();
      });
    }
    if (_requestedImage || kIsWeb) return;
    _requestedImage = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadImage();
    });
  }

  Future<void> _loadImage() async {
    final search = context.read<AiPropertySearchProvider>();
    final imageUrl = await search.fetchImageFor(widget.listing);
    if (!mounted) return;
    setState(() => _imageUrl = imageUrl);
  }

  Future<void> _loadSavedState() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;
    try {
      final saved = await context
          .read<SavedAiListingsRepository>()
          .contains(userId, widget.listing.url);
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {
      // La tarjeta permanece utilizable aunque no se pueda consultar el guardado.
    }
  }

  Future<void> _toggleSaved() async {
    if (_saving) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar avisos.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = context.read<SavedAiListingsRepository>();
      if (_isSaved) {
        await repository.remove(userId, widget.listing.url);
      } else {
        await repository.save(userId, widget.listing);
      }
      if (!mounted) return;
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Aviso guardado.' : 'Aviso eliminado.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el guardado.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _thumbnail() {
    final placeholder = Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.home_outlined,
        size: 34,
        color: AppColors.mediumGray,
      ),
    );
    final imageUrl = _imageUrl;
    if (imageUrl == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : placeholder,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }

  Future<void> _openListing() async {
    await launchUrl(
      widget.listing.url,
      mode: LaunchMode.externalApplication,
    );
  }

  String _portalName(String source) => switch (source) {
        'fincaraiz' => 'Fincaraíz',
        'metrocuadrado' => 'Metrocuadrado',
        'ciencuadras' => 'Ciencuadras',
        _ => source,
      };

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final textTheme = Theme.of(context).textTheme;
    final location = listing.neighborhood ?? listing.address;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _openListing,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.public,
                                  size: 16,
                                  color: AppColors.mediumGray,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Fuente: ${_portalName(listing.source)}',
                                  style: textTheme.labelMedium,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusReviewBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'En revisión',
                              style: TextStyle(
                                color: AppColors.statusReview,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        listing.priceCop == null
                            ? 'Precio no publicado'
                            : formatPrice(listing.priceCop!.toDouble()),
                        style: textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      if (location != null && location.isNotEmpty)
                        Text(
                          location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Resultado de la web, no verificado por la comunidad. '
              'Fuente: ${_portalName(listing.source)}',
              style: textTheme.bodySmall,
            ),
            if (!listing.linkVerified)
              Text(
                'Enlace no verificado.',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.statusReview,
                ),
              ),
            if (listing.approximateLocation)
              Text('Ubicación aproximada.', style: textTheme.bodySmall),
            if (listing.missingData.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'No se pudo obtener: ${listing.missingData.join(', ')}. '
                  'Consulte el enlace original.',
                  style: textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openListing,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver publicación original'),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _saving ? null : _toggleSaved,
                  tooltip: _isSaved ? 'Quitar de guardados' : 'Guardar aviso',
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleSearchSuggestions extends StatefulWidget {
  final String html;

  const _GoogleSearchSuggestions({required this.html});

  @override
  State<_GoogleSearchSuggestions> createState() =>
      _GoogleSearchSuggestionsState();
}

class _GoogleSearchSuggestionsState extends State<_GoogleSearchSuggestions> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);
  }

  @override
  void didUpdateWidget(covariant _GoogleSearchSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.html != oldWidget.html) {
      _controller.loadHtmlString(widget.html);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: WebViewWidget(controller: _controller),
    );
  }
}
