import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/shimmer_loading.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/banner_model.dart';
import '../../services/api_service.dart';

class ManageBannersPage extends StatefulWidget {
  const ManageBannersPage({super.key});

  @override
  State<ManageBannersPage> createState() => _ManageBannersPageState();
}

class _ManageBannersPageState extends State<ManageBannersPage> {
  final ApiService apiService = ApiService();

  final Color primaryGreen = const Color(0xFF1B8F3A);
  final Color lightGreen = const Color(0xFFEAF8EE);

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  List<BannerModel> banners = [];
  File? selectedImage;

  bool isLoading = false;
  bool isSaving = false;
  int? editingBannerId;

  @override
  void initState() {
    super.initState();
    fetchBanners();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> fetchBanners() async {
    setState(() => isLoading = true);

    try {
      final data = await apiService.getBanners();
      setState(() {
        banners = data;
      });
    } catch (e) {
      showMessage(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();

    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
      });
    }
  }

  Future<void> saveBanner() async {
    if (titleController.text.trim().isEmpty) {
      showMessage("Please enter title");
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      showMessage("Please enter description");
      return;
    }

    if (editingBannerId == null && selectedImage == null) {
      showMessage("Please select banner image");
      return;
    }

    setState(() => isSaving = true);

    try {
      if (editingBannerId == null) {
        await apiService.addBanner(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          image: selectedImage,
        );

        showMessage("Banner added successfully");
      } else {
        await apiService.updateBanner(
          bannerId: editingBannerId!,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          image: selectedImage,
        );

        showMessage("Banner updated successfully");
      }

      clearForm();
      await fetchBanners();
    } catch (e) {
      showMessage(e.toString());
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> deleteBanner(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Delete Banner"),
          content: const Text("Are you sure you want to delete this banner?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await apiService.deleteBanner(bannerId: id);
      showMessage("Banner deleted successfully");
      await fetchBanners();
    } catch (e) {
      showMessage(e.toString());
    }
  }

  void editBanner(BannerModel banner) {
    setState(() {
      editingBannerId = banner.id;
      titleController.text = banner.title;
      descriptionController.text = banner.description;
      selectedImage = null;
    });
  }

  void clearForm() {
    setState(() {
      editingBannerId = null;
      titleController.clear();
      descriptionController.clear();
      selectedImage = null;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.replaceAll("Exception:", "").trim())),
    );
  }

  String imageUrl(String image) {
    if (image.startsWith("http")) return image;
    return image;
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Banners",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Add, edit and delete app banners",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: pickImage,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.green.shade100),
              ),
              child: selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 45,
                          color: primaryGreen,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          editingBannerId == null
                              ? "Select Banner Image"
                              : "Tap to Change Image",
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: "Title",
              prefixIcon: Icon(Icons.title_rounded, color: primaryGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Description",
              prefixIcon: Icon(Icons.description_rounded, color: primaryGreen),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : saveBanner,
                  icon: isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    editingBannerId == null ? "Add Banner" : "Update Banner",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (editingBannerId != null) ...[
                const SizedBox(width: 10),
                IconButton(
                  onPressed: clearForm,
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildBannerCard(BannerModel banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.image.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: Image.network(
                imageUrl(banner.image),
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Container(
                    height: 150,
                    color: lightGreen,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: primaryGreen,
                      size: 40,
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        banner.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => editBanner(banner),
                  icon: Icon(Icons.edit_rounded, color: primaryGreen),
                ),
                IconButton(
                  onPressed: () => deleteBanner(banner.id),
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBannerList() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ShopsListShimmer(itemCount: 2),
      );
    }

    if (banners.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text(
            "No banners found",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: banners.map(buildBannerCard).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFF9),
      body: SafeArea(
        child: Column(
          children: [
            buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: fetchBanners,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      buildForm(),
                      const SizedBox(height: 22),
                      buildBannerList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}