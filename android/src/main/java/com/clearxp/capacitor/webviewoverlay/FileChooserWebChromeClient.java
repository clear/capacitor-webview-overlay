package com.clearxp.capacitor.webviewoverlay;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Log;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebView;

import androidx.core.content.FileProvider;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

/**
 * A custom WebChromeClient designed to handle file chooser requests from a WebView.
 * This implementation allows for both capturing a new photo with the camera and
 * selecting an existing file from the device's storage.
 */
public class FileChooserWebChromeClient extends WebChromeClient {

    private static final String TAG = "CxpFileChooserClient";
    public static final int INPUT_FILE_REQUEST_CODE = 1;

    // NOTE: Using static fields is a simplification to bridge the Activity and the plugin.
    // This is a fragile approach and can cause issues if multiple WebViews are used
    // simultaneously or if the Android OS terminates and restores the app. A more
    // robust solution would require a more complex architecture.
    public static ValueCallback<Uri[]> mFilePathCallback;
    public static String mCameraPhotoPath;

    private Activity activity;

    public FileChooserWebChromeClient(Activity activity) {
        this.activity = activity;

        Log.d(TAG, "Creating FileChooserWebChromeClient");
    }

    /**
     * Creates a temporary image file to be used for storing the photo from the camera.
     * @return The created File object.
     * @throws IOException If the file could not be created.
     */
    private File createImageFile() throws IOException {
        Log.d(TAG, "createImageFile");

        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date());
        String imageFileName = "JPEG_" + timeStamp + "_";

        // Use the app's private external files directory for better compatibility with Scoped Storage.
        File storageDir = activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        if (storageDir != null && !storageDir.exists()) {
            storageDir.mkdirs();
        }

        File imageFile = File.createTempFile(imageFileName, ".jpg", storageDir);
        mCameraPhotoPath = imageFile.getAbsolutePath();
        return imageFile;
    }

    /**
     * This method is called by the WebView when a file input is clicked.
     */
    @Override
    public boolean onShowFileChooser(WebView webView, ValueCallback<Uri[]> filePathCallback, FileChooserParams fileChooserParams) {
        Log.d(TAG, "onShowFileChooser");

        // If there's already a callback, cancel it to avoid issues.
        if (mFilePathCallback != null) {
            mFilePathCallback.onReceiveValue(null);
            mFilePathCallback = null;
        }

        mFilePathCallback = filePathCallback;

        // Create an intent to launch the camera
        Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
        if (takePictureIntent.resolveActivity(activity.getPackageManager())!= null) {
            Log.d(TAG, "onShowFileChooser - take picture");

            File photoFile = null;
            try {
                photoFile = createImageFile();
            } catch (IOException ex) {
                Log.e(TAG, "Unable to create Image File", ex);
            }

            if (photoFile != null) {
                Uri photoURI = FileProvider.getUriForFile(
                        activity,
                        activity.getPackageName() + ".fileprovider",
                        photoFile
                );

                takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI);
                takePictureIntent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);

                // Grant permission to all camera apps that can handle this intent
                List<ResolveInfo> resInfoList = activity.getPackageManager().queryIntentActivities(takePictureIntent, 0);

                for (ResolveInfo resolveInfo : resInfoList) {
                    String packageName = resolveInfo.activityInfo.packageName;
                    activity.grantUriPermission(packageName, photoURI, Intent.FLAG_GRANT_WRITE_URI_PERMISSION |  Intent.FLAG_GRANT_READ_URI_PERMISSION);
                }
            } else {
                takePictureIntent = null;
            }
        }

        // Create an intent to open the file picker
        Intent contentSelectionIntent = new Intent(Intent.ACTION_GET_CONTENT);
        contentSelectionIntent.addCategory(Intent.CATEGORY_OPENABLE);
        contentSelectionIntent.setType("*/*"); // You can restrict this to "image/*" etc.

        // Create an array of intents to include the camera option
        Intent[] intentArray;
        if (takePictureIntent != null) {
            intentArray = new Intent[]{ takePictureIntent };
        } else {
            intentArray = new Intent[]{};
        }

        Log.d(TAG, "onShowFileChooser - choose intent");

        // The main chooser intent that wraps the file picker
        Intent chooserIntent = new Intent(Intent.ACTION_CHOOSER);
        chooserIntent.putExtra(Intent.EXTRA_INTENT, contentSelectionIntent);
        chooserIntent.putExtra(Intent.EXTRA_TITLE, "Choose Action");
        // Add the camera intent as an extra option in the chooser
        chooserIntent.putExtra(Intent.EXTRA_INITIAL_INTENTS, intentArray);

        activity.startActivityForResult(chooserIntent, INPUT_FILE_REQUEST_CODE);
        return true; // Return true to indicate we've handled the event.
    }
}
