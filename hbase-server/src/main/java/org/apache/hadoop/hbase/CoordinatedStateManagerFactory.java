/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.hadoop.hbase;

import org.apache.hadoop.hbase.classification.InterfaceAudience;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.hbase.coordination.ZkCoordinatedStateManager;
import org.apache.hadoop.util.ReflectionUtils;

/**
 * Creates instance of {@link CoordinatedStateManager}
 * based on configuration.
 */
@InterfaceAudience.Private
public class CoordinatedStateManagerFactory {

  /**
   * 三个参数分别表示:
   * 1.自定义的类的名字(用于获取相应的class文件),
   * 2.表示默认的HBase的协同管理类ZKCoordinatedStateManager,
   * 3.用于验证所获取的class是不是从CoordinatedManager继承的.
   * 默认的class是通过zookeeper实现CoordinatedManager对HBase的集群进行管理
   * 然后通过反射机制形成类的实例。
   * Creates consensus provider from the given configuration.
   * @param conf Configuration
   * @return Implementation of  {@link CoordinatedStateManager}
   */
  public static CoordinatedStateManager getCoordinatedStateManager(Configuration conf) {
    Class<? extends CoordinatedStateManager> coordinatedStateMgrKlass =
      conf.getClass(HConstants.HBASE_COORDINATED_STATE_MANAGER_CLASS,
        ZkCoordinatedStateManager.class, CoordinatedStateManager.class);
    return ReflectionUtils.newInstance(coordinatedStateMgrKlass, conf);
  }
}
