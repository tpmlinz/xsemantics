/*******************************************************************************
 * Copyright (c) 2013-2017 Lorenzo Bettini.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * Contributors:
 *   Lorenzo Bettini - Initial contribution and API
 *******************************************************************************/

package org.eclipse.xsemantics.dsl.tests.utils.ui

import com.google.inject.Inject
import java.util.List
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.jdt.core.IJavaProject
import org.eclipse.jdt.core.JavaCore
import org.eclipse.xtext.ui.XtextProjectHelper
import org.eclipse.xtext.ui.testing.util.JavaProjectSetupUtil
import org.eclipse.xtext.ui.util.PluginProjectFactory

class PluginProjectHelper {
	
	@Inject PluginProjectFactory projectFactory

	def IJavaProject createJavaPluginProject(String projectName, List<String> requiredBundles) {
		projectFactory.setProjectName(projectName);
		projectFactory.addFolders(newArrayList("src", "xsemantics-gen"));
		projectFactory.addBuilderIds(
			JavaCore.BUILDER_ID, 
			"org.eclipse.pde.ManifestBuilder",
			"org.eclipse.pde.SchemaBuilder",
			XtextProjectHelper.BUILDER_ID);
		projectFactory.addProjectNatures(
			JavaCore.NATURE_ID, 
			"org.eclipse.pde.PluginNature", 
			XtextProjectHelper.NATURE_ID
		);
		projectFactory.addRequiredBundles(requiredBundles);
		val result = projectFactory.createProject(new NullProgressMonitor(), null);
		JavaProjectSetupUtil.makeJava5Compliant(JavaCore.create(result));
		return JavaProjectSetupUtil.findJavaProject(projectName);
	}

}