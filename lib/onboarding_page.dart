import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'landing_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSport;
  String _zipCode = '';
  double _radius = 10;
  String? _error;
  bool _isLoading = false;

  bool get _isFormValid =>
      _selectedSport != null &&
      _zipCode.length == 5 &&
      RegExp(r'^[0-9]{5}\u0000?$').hasMatch(_zipCode);

  String? _validateZip(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your zip code';
    }
    final zipPattern = RegExp(r'^[0-9]{5}\u0000?$');
    if (!zipPattern.hasMatch(value.trim())) {
      return 'Enter a valid 5-digit US zip code';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _selectedSport == null) {
      setState(() {
        _error = _selectedSport == null ? 'Please select a sport' : null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
    });
    _formKey.currentState!.save();
    print('Sport: $_selectedSport, Zip: $_zipCode, Radius: $_radius');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LandingPage()),
    );
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tell us about you')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'What sport are you interested in?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ShadRadioGroupFormField<String>(
                  label: const Text('What sport are you interested in?'),
                  items: const [
                    ShadRadio(value: 'running', label: Text('Running')),
                    ShadRadio(value: 'cycling', label: Text('Cycling')),
                  ],
                  validator: (v) {
                    if (v == null) return 'Please select a sport';
                    return null;
                  },
                  onSaved: (v) => _selectedSport = v,
                ),
                const SizedBox(height: 24),
                ShadInputFormField(
                  keyboardType: TextInputType.number,
                  validator: _validateZip,
                  onChanged: (v) {
                    setState(() {
                      _zipCode = v ?? '';
                    });
                  },
                  onSaved: (v) => _zipCode = v ?? '',
                  placeholder: const Text('Zip Code'),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Text('Preferred activity radius:'),
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: '${_radius.round()} mi',
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ),
                    Text('${_radius.round()} mi'),
                  ],
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ShadAlert.destructive(
                      title: const Text('Error'),
                      description: Text(_error!),
                    ),
                  ),
                const SizedBox(height: 24),
                ShadButton(
                  onPressed: _isFormValid && !_isLoading ? _submit : null,
                  child: _isLoading
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
