package com.appblade.framework.feedback;

import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.URI;

import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.mime.HttpMultipartMode;
import org.apache.http.entity.mime.MultipartEntity;
import org.apache.http.entity.mime.content.ByteArrayBody;
import org.apache.http.entity.mime.content.ContentBody;
import org.apache.http.entity.mime.content.StringBody;

import com.appblade.framework.AppBlade;
import com.appblade.framework.WebServiceHelper;
import com.appblade.framework.WebServiceHelper.HttpMethod;
import com.appblade.framework.customparams.CustomParamData;
import com.appblade.framework.customparams.CustomParamDataHelper;
import com.appblade.framework.utils.Base64;
import com.appblade.framework.utils.HttpClientProvider;
import com.appblade.framework.utils.HttpUtils;
import com.appblade.framework.utils.IOUtils;
import com.appblade.framework.utils.StringUtils;

import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.graphics.Bitmap;
import android.graphics.Bitmap.CompressFormat;
import android.util.Log;
import android.view.Gravity;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

public class FeedbackHelper {

	public static boolean postFeedback(FeedbackData data) {
		return postFeedbackWithCustomParams(data, null);
	}		
	public static boolean postFeedbackWithCustomParams(FeedbackData data,
				CustomParamData paramData) {
		boolean success = false;
		HttpClient client = HttpClientProvider.newInstance("Android");
		String sharedBoundary = AppBlade.genDynamicBoundary();

		try
		{
			String urlPath = String.format(WebServiceHelper.ServicePathFeedbackFormat, AppBlade.appInfo.AppId, AppBlade.appInfo.Ext);
			String url = WebServiceHelper.getUrl(urlPath);

			Log.d(AppBlade.LogTag, (paramData == null ? "no paramData" : "Param Data " + paramData.toString()));

			final MultipartEntity content = FeedbackHelper.getPostFeedbackBody(data, paramData, sharedBoundary);

			HttpPost request = new HttpPost();
			request.setEntity(content);
			
			
			ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
			content.writeTo(outputStream);
			String multipartRawContent = outputStream.toString();
			
			String authHeader = WebServiceHelper.getHMACAuthHeader(AppBlade.appInfo, urlPath, multipartRawContent, HttpMethod.POST);

			Log.d(AppBlade.LogTag, urlPath);
			Log.d(AppBlade.LogTag, url);
			Log.d(AppBlade.LogTag, authHeader);

			request.setURI(new URI(url));
			request.addHeader("Content-Type", HttpUtils.ContentTypeMultipartFormData + "; boundary=" + sharedBoundary);
			request.addHeader("Authorization", authHeader);

			WebServiceHelper.addCommonHeaders(request);
			
			
			HttpResponse response = null;
			response = client.execute(request);
			if(response != null && response.getStatusLine() != null)
			{
				int statusCode = response.getStatusLine().getStatusCode();
				int statusCategory = statusCode / 100;

				Log.d(AppBlade.LogTag, "Feedback returned: " + statusCode);

				
				if(statusCategory == 2)
					success = true;
			}else{
				Log.d(AppBlade.LogTag, "Feedback returned null response ");
			}

		}
		catch(Exception ex)
		{
			Log.d(AppBlade.LogTag, String.format("%s %s", ex.getClass().getSimpleName(), ex.getMessage()));
			ex.printStackTrace();
		}

		IOUtils.safeClose(client);
		
		return success;
	}

	
	
	public static String getLogData(){
		try {
			Process process = Runtime.getRuntime().exec("logcat -d");
			BufferedReader bufferedReader = new BufferedReader(
					new InputStreamReader(process.getInputStream()));

			StringBuilder log = new StringBuilder();
			String line;
			while ((line = bufferedReader.readLine()) != null) {
				log.append(line);
				log.append("\n");
			}
			return log.toString();
		} catch (IOException e) {
		}

		return "";
	}

	public static void getFeedbackData(Context context, FeedbackData data,
			final OnFeedbackDataAcquiredListener listener) {
		AlertDialog.Builder dialog = new AlertDialog.Builder(context);
		dialog.setTitle("Feedback");

		final LinearLayout wrapperView = new LinearLayout(context);
		wrapperView.setOrientation(LinearLayout.VERTICAL);
		
		
		final LinearLayout checkboxLayout = new LinearLayout(context);
		checkboxLayout.setGravity(Gravity.CENTER_VERTICAL);
		final CheckBox screenshotCheckBox = new CheckBox(context);
		screenshotCheckBox.setChecked(true); 
		checkboxLayout.addView(screenshotCheckBox);
		
		final TextView screenshotCheckboxTitle = new TextView(context);
		screenshotCheckboxTitle.setText("Send Screenshot");
		checkboxLayout.addView(screenshotCheckboxTitle);
		wrapperView.addView(checkboxLayout);
		
		final EditText editText = new EditText(context);
		editText.setLines(5);
		editText.setGravity(Gravity.TOP);
		editText.setHint("Enter any feedback...");
		wrapperView.addView(editText);
		
		
		dialog.setView(wrapperView);
		
		if (data == null)
			data = new FeedbackData();
		
		final FeedbackData fData = data;
		
		dialog.setPositiveButton("Submit", new DialogInterface.OnClickListener() {
			public void onClick(DialogInterface dialog, int which) {
				fData.Notes = editText.getText().toString();
				fData.sendScreenshotConfirmed = screenshotCheckBox.isChecked();
				listener.OnFeedbackDataAcquired(fData);
			}
		});
		
		dialog.setNegativeButton("Cancel", null);
		
		dialog.show();
	}

	public static MultipartEntity getPostFeedbackBody(FeedbackData data, CustomParamData paramsData, String boundary) {
		MultipartEntity entity = new MultipartEntity(HttpMultipartMode.BROWSER_COMPATIBLE, boundary, null);
		try
		{
			ContentBody notesBody = new StringBody(data.Notes);
			entity.addPart("feedback[notes]", notesBody);
			if (data.Screenshot != null && data.sendScreenshotConfirmed) {
				if (StringUtils.isNullOrEmpty(data.ScreenshotName))
					data.ScreenshotName = "FeedbackScreenshot";
				// re-encode the bytes as base64 so AppBlade will be able to handle it.
				byte[] screenshotBytes = getBytesFromBitmap(data.Screenshot);
				screenshotBytes = Base64.encode(screenshotBytes, 0);
				ContentBody screenshotBody = new ByteArrayBody(screenshotBytes,	HttpUtils.ContentTypeOctetStream, "base64:" + data.ScreenshotName);
				entity.addPart("feedback[screenshot]", screenshotBody);
			}
			if(paramsData != null){
				ContentBody customParamsBody = new ByteArrayBody(paramsData.toString().getBytes("utf-8"),
																 HttpUtils.ContentTypeJson,
																 CustomParamDataHelper.customParamsFileName);
				entity.addPart("custom_params", customParamsBody);
			}
		} 
		catch (IOException e) {
			Log.d(AppBlade.LogTag, e.toString());
		}
		
		return entity;
	}

	public static byte[] getBytesFromBitmap(Bitmap bitmap) {
		ByteArrayOutputStream out = new ByteArrayOutputStream();
		bitmap.compress(CompressFormat.PNG, 100, out);
		return out.toByteArray();
	}


	public static String formatNewScreenshotFileName() {
		String toRet = "";
		toRet = "Feedback-" + (System.currentTimeMillis() / 1000L) + ".png";
		return toRet ;
	}
	
	/**
	 * Persistent storage functionality (that's not in FeedbackData)
	 */
	public static String formatNewScreenshotFileLocation() {
		String toRet = "";
		toRet = AppBlade.rootDir + "/" + formatNewScreenshotFileName();
		Log.d(AppBlade.LogTag, toRet);
		return toRet ;
	}



}
